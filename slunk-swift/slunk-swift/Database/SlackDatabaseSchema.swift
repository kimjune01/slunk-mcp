import Foundation
import GRDB
import SQLiteVec

// MARK: - Slack-Specific Database Schema with Deduplication

/// Database schema manager for Slack message storage with deduplication and vector search
/// Integrates GRDB for relational data and SQLiteVec for semantic search capabilities
public class SlackDatabaseSchema {
    let databaseURL: URL
    var database: DatabaseQueue?
    
    // MARK: - Initialization
    
    init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }
    
    convenience init() throws {
        let persistentURL = try Self.getPersistentDatabaseURL()
        self.init(databaseURL: persistentURL)
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Setup
    
    func initializeDatabase() async throws {
        // Initialize SQLiteVec extension
        try SQLiteVec.initialize()
        
        // Open database connection
        try openDatabase()
        
        // Create all tables and indexes
        try await createAllTables()
        try await createIndexes()
    }
    
    private func createAllTables() async throws {
        try await createSlackMessageTable()
        try await createReactionsTable()
        try await createIngestionLogTable()
        try await createVectorTable()
    }
    
    static func getPersistentDatabaseURL() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Slunk")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        return appDir.appendingPathComponent("slack_store.db")
    }
    
    private func openDatabase() throws {
        database = try DatabaseQueue(path: databaseURL.path)
    }
    
    private func closeDatabase() {
        database = nil
    }
    
    // MARK: - Table Creation
    
    func createSlackMessageTable() async throws {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        let sql = """
            CREATE TABLE IF NOT EXISTS slack_messages (
                id TEXT PRIMARY KEY,              -- Slack message timestamp as unique ID
                workspace TEXT NOT NULL,
                channel TEXT NOT NULL,
                sender TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp DATETIME NOT NULL,
                
                -- Thread information
                thread_ts TEXT,                   -- Parent thread timestamp
                
                -- Message metadata (JSON fields)
                mentions TEXT,                    -- JSON array: ["@john", "@channel"]
                attachment_names TEXT,            -- JSON array: ["file1.pdf", "image.png"]
                
                -- Deduplication and versioning
                content_hash TEXT NOT NULL,       -- SHA256 hash for verification
                version INTEGER DEFAULT 1,       -- For tracking edits
                edited_at DATETIME,               -- When message was last edited
                
                -- Tracking
                ingested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                
                -- Computed fields for indexing
                date_only DATE GENERATED ALWAYS AS (DATE(timestamp)) STORED,
                month_year TEXT GENERATED ALWAYS AS (strftime('%Y-%m', timestamp)) STORED,
                
                -- Composite unique constraint
                UNIQUE(workspace, channel, id)
            )
        """
        
        try await database.write { db in
            try db.execute(sql: sql)
        }
    }
    
    func createReactionsTable() async throws {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        let sql = """
            CREATE TABLE IF NOT EXISTS slack_reactions (
                message_id TEXT NOT NULL,
                emoji TEXT NOT NULL,
                count INTEGER NOT NULL DEFAULT 0,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                
                PRIMARY KEY (message_id, emoji),
                FOREIGN KEY (message_id) REFERENCES slack_messages(id) ON DELETE CASCADE
            )
        """
        
        try await database.write { db in
            try db.execute(sql: sql)
        }
    }
    
    func createIngestionLogTable() async throws {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        let sql = """
            CREATE TABLE IF NOT EXISTS ingestion_log (
                session_id TEXT NOT NULL,
                workspace TEXT NOT NULL,
                channel TEXT NOT NULL,
                last_message_timestamp TEXT,
                ingested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                message_count INTEGER DEFAULT 0,
                new_messages INTEGER DEFAULT 0,
                updated_messages INTEGER DEFAULT 0,
                duplicate_messages INTEGER DEFAULT 0,
                
                PRIMARY KEY (session_id, workspace, channel)
            )
        """
        
        try await database.write { db in
            try db.execute(sql: sql)
        }
    }
    
    func createVectorTable() async throws {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        // Create vec0 virtual table for message embeddings
        let sql = """
            CREATE VIRTUAL TABLE IF NOT EXISTS slack_message_embeddings USING vec0(
                embedding float[512],
                message_id text
            )
        """
        
        try await database.write { db in
            try db.execute(sql: sql)
        }
    }
    
    func createIndexes() async throws {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        let indexes = [
            // Core message indexes
            "CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON slack_messages(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_messages_channel ON slack_messages(workspace, channel)",
            "CREATE INDEX IF NOT EXISTS idx_messages_sender ON slack_messages(sender)",
            "CREATE INDEX IF NOT EXISTS idx_messages_date_only ON slack_messages(date_only)",
            "CREATE INDEX IF NOT EXISTS idx_messages_content_hash ON slack_messages(content_hash)",
            
            // Thread indexes
            "CREATE INDEX IF NOT EXISTS idx_messages_thread ON slack_messages(thread_ts)",
            
            // Search indexes
            "CREATE INDEX IF NOT EXISTS idx_messages_content_fts ON slack_messages(content)",
            
            // Reaction indexes
            "CREATE INDEX IF NOT EXISTS idx_reactions_message ON slack_reactions(message_id)",
            "CREATE INDEX IF NOT EXISTS idx_reactions_emoji ON slack_reactions(emoji)",
            
            // Ingestion log indexes
            "CREATE INDEX IF NOT EXISTS idx_ingestion_workspace_channel ON ingestion_log(workspace, channel)",
            "CREATE INDEX IF NOT EXISTS idx_ingestion_timestamp ON ingestion_log(ingested_at)"
        ]
        
        for indexSQL in indexes {
            try await database.write { db in
                try db.execute(sql: indexSQL)
            }
        }
    }
    
    // MARK: - Message Deduplication Logic
    
    func processMessage(_ message: SlackMessage, workspace: String, channel: String) async throws -> DeduplicationResult {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        let messageId = message.deduplicationKey
        let contentHash = message.contentHash
        
        // Check if message exists
        let existingSQL = "SELECT * FROM slack_messages WHERE id = ? AND workspace = ? AND channel = ?"
        let existing = try await database.read { db in
            return try Row.fetchAll(db, sql: existingSQL, arguments: [messageId, workspace, channel])
        }
        
        if let existingRow = existing.first {
            let existingHash: String = existingRow["content_hash"] ?? ""
            let existingContent: String = existingRow["content"] ?? ""
            
            // Check if content changed (message edited)
            if existingHash != contentHash || existingContent != message.content {
                try await updateMessage(message, messageId: messageId, workspace: workspace, channel: channel)
                return .updated(messageId)
            }
            
            // Check if reactions changed
            if let existingReactions = try await getMessageReactions(messageId: messageId),
               let newReactions = message.metadata?.reactions,
               !reactionsEqual(existingReactions, newReactions) {
                try await updateReactions(messageId: messageId, reactions: newReactions)
                return .reactionsUpdated(messageId)
            }
            
            return .duplicate
        }
        
        // New message - insert
        try await insertNewMessage(message, messageId: messageId, workspace: workspace, channel: channel)
        return .new(messageId)
    }
    
    private func insertNewMessage(_ message: SlackMessage, messageId: String, workspace: String, channel: String) async throws {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        // Serialize JSON fields
        let mentionsJSON = try serializeStringArray(message.metadata?.mentions ?? [])
        let attachmentsJSON = try serializeStringArray(message.metadata?.attachmentNames ?? [])
        
        let sql = """
            INSERT INTO slack_messages (
                id, workspace, channel, sender, content, timestamp,
                thread_ts, mentions, attachment_names, content_hash,
                version, edited_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        try await database.write { db in
            try db.execute(sql: sql, arguments: [
                messageId,
                workspace,
                channel,
                message.sender,
                message.content,
                message.timestamp,
                message.threadId,
                mentionsJSON,
                attachmentsJSON,
                message.contentHash,
                message.metadata?.version ?? 1,
                message.metadata?.editedAt
            ])
        }
        
        // Insert reactions if any
        if let reactions = message.metadata?.reactions {
            try await insertReactions(messageId: messageId, reactions: reactions)
        }
    }
    
    private func updateMessage(_ message: SlackMessage, messageId: String, workspace: String, channel: String) async throws {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        let mentionsJSON = try serializeStringArray(message.metadata?.mentions ?? [])
        let attachmentsJSON = try serializeStringArray(message.metadata?.attachmentNames ?? [])
        
        let sql = """
            UPDATE slack_messages SET
                content = ?, content_hash = ?, version = version + 1,
                edited_at = ?, mentions = ?, attachment_names = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ? AND workspace = ? AND channel = ?
        """
        
        try await database.write { db in
            try db.execute(sql: sql, arguments: [
                message.content,
                message.contentHash,
                message.metadata?.editedAt ?? Date(),
                mentionsJSON,
                attachmentsJSON,
                messageId,
                workspace,
                channel
            ])
        }
    }
    
    private func insertReactions(messageId: String, reactions: [String: Int]) async throws {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        // Clear existing reactions
        try await database.write { db in
            try db.execute(sql: "DELETE FROM slack_reactions WHERE message_id = ?", arguments: [messageId])
            
            // Insert new reactions
            for (emoji, count) in reactions {
                let sql = "INSERT INTO slack_reactions (message_id, emoji, count) VALUES (?, ?, ?)"
                try db.execute(sql: sql, arguments: [messageId, emoji, count])
            }
        }
    }
    
    private func updateReactions(messageId: String, reactions: [String: Int]) async throws {
        try await insertReactions(messageId: messageId, reactions: reactions)
    }
    
    private func getMessageReactions(messageId: String) async throws -> [String: Int]? {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        let sql = "SELECT emoji, count FROM slack_reactions WHERE message_id = ?"
        let results = try await database.read { db in
            return try Row.fetchAll(db, sql: sql, arguments: [messageId])
        }
        
        if results.isEmpty {
            return nil
        }
        
        var reactions: [String: Int] = [:]
        for row in results {
            let emoji: String = row["emoji"]
            let count: Int = row["count"]
            reactions[emoji] = count
        }
        
        return reactions
    }
    
    private func reactionsEqual(_ existing: [String: Int], _ new: [String: Int]) -> Bool {
        return existing == new
    }
    
    // MARK: - Ingestion Tracking
    
    func logIngestionSession(workspace: String, channel: String, stats: IngestionStats) async throws {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        let sessionId = UUID().uuidString
        let sql = """
            INSERT INTO ingestion_log (
                session_id, workspace, channel, message_count,
                new_messages, updated_messages, duplicate_messages
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        try await database.write { db in
            try db.execute(sql: sql, arguments: [
                sessionId,
                workspace,
                channel,
                stats.totalProcessed,
                stats.newMessages,
                stats.updates,
                stats.duplicates
            ])
        }
    }
    
    // MARK: - Helper Methods
    
    private func serializeStringArray(_ array: [String]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: array)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    
    private func deserializeStringArray(_ jsonString: String) throws -> [String] {
        guard let data = jsonString.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return array
    }
    
    // MARK: - Database Statistics
    
    public func getMessageCount() async throws -> Int {
        guard let db = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        return try await db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM slack_messages") ?? 0
        }
    }
    
    public func getWorkspaceCount() async throws -> Int {
        guard let db = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        return try await db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(DISTINCT workspace) FROM slack_messages") ?? 0
        }
    }
    
    public func isDatabaseOpen() -> Bool {
        return database != nil
    }
    
    func getDatabaseSize() async throws -> Int64 {
        guard let db = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        return try await db.read { db in
            try Int64.fetchOne(db, sql: "SELECT page_count * page_size FROM pragma_page_count(), pragma_page_size()") ?? 0
        }
    }
}

// MARK: - Supporting Types

enum DeduplicationResult {
    case new(String)              // Message ID
    case duplicate
    case updated(String)          // Updated message ID
    case reactionsUpdated(String) // Message ID with updated reactions
}

struct IngestionStats {
    var totalProcessed: Int = 0
    var newMessages: Int = 0
    var updates: Int = 0
    var duplicates: Int = 0
    var reactionUpdates: Int = 0
}

enum SlackDatabaseError: Error {
    case databaseNotOpen
    case insertFailed(String)
    case updateFailed(String)
    case queryFailed(String)
    case serializationFailed(String)
}

extension SlackDatabaseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .databaseNotOpen:
            return "Database is not open"
        case .insertFailed(let message):
            return "Insert failed: \(message)"
        case .updateFailed(let message):
            return "Update failed: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        case .serializationFailed(let message):
            return "Serialization failed: \(message)"
        }
    }
}