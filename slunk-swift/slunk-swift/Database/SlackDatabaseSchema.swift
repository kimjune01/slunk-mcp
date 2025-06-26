import Foundation
import GRDB
import SQLiteVec
import NaturalLanguage

// MARK: - Slack-Specific Database Schema with Deduplication

/// Database schema manager for Slack message storage with deduplication and vector search
/// Integrates GRDB for relational data and SQLiteVec for semantic search capabilities
public class SlackDatabaseSchema {
    let databaseURL: URL
    var database: DatabaseQueue?
    private let databaseConfig: GRDB.Configuration
    
    // MARK: - Initialization
    
    init(databaseURL: URL) {
        self.databaseURL = databaseURL
        
        // Configure database for concurrent access
        var config = GRDB.Configuration()
        config.prepareDatabase { db in
            // Check if already in WAL mode before setting to avoid lock conflicts
            let currentMode = try String.fetchOne(db, sql: "PRAGMA journal_mode") ?? ""
            if currentMode.uppercased() != "WAL" {
                try db.execute(sql: "PRAGMA journal_mode = WAL")
            }
            // Set busy timeout to handle concurrent access
            try db.execute(sql: "PRAGMA busy_timeout = 30000") // 30 seconds
        }
        self.databaseConfig = config
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
    
    private func openDatabase() throws {
        var retryCount = 0
        let maxRetries = 3
        
        while retryCount < maxRetries {
            do {
                database = try DatabaseQueue(path: databaseURL.path, configuration: databaseConfig)
                return
            } catch {
                if error.localizedDescription.contains("database is locked") && retryCount < maxRetries - 1 {
                    // Wait briefly and retry
                    Thread.sleep(forTimeInterval: 0.1 * Double(retryCount + 1)) // 100ms, 200ms, 300ms
                    retryCount += 1
                    continue
                }
                throw error
            }
        }
    }
    
    private func closeDatabase() {
        database = nil
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
    
    // MARK: - Connection Management
    
    /// Uses the main database connection for operations to avoid lock conflicts
    private func withDatabaseConnection<T>(_ operation: (DatabaseQueue) async throws -> T) async throws -> T {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        return try await operation(database)
    }
    
    /// Legacy method for read operations - now uses main database connection
    private func withDatabase<T>(_ operation: (DatabaseQueue) throws -> T) throws -> T {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        return try operation(database)
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
        
        let messageId = message.id  // Use the actual message ID (timestamp-based)
        let contentHash = message.contentHash
        
        // Check if an identical message already exists using the deduplication key
        let duplicateCheckSQL = """
            SELECT id, content_hash, content, sender 
            FROM slack_messages 
            WHERE workspace = ? AND channel = ? AND sender = ? AND content = ?
            ORDER BY timestamp DESC
            LIMIT 1
        """
        
        let duplicates = try await database.read { db in
            return try Row.fetchAll(db, sql: duplicateCheckSQL, arguments: [
                workspace, channel, message.sender, message.content
            ])
        }
        
        if let existingRow = duplicates.first {
            let existingId: String = existingRow["id"]
            
            // It's a duplicate - same content, channel, and sender
            // Check if reactions need updating
            if let existingReactions = try await getMessageReactions(messageId: existingId),
               let newReactions = message.metadata?.reactions,
               !reactionsEqual(existingReactions, newReactions) {
                try await updateReactions(messageId: existingId, reactions: newReactions)
                return .reactionsUpdated(existingId)
            }
            
            return .duplicate
        }
        
        // Check if this specific message ID already exists (for updates)
        let existingByIdSQL = "SELECT * FROM slack_messages WHERE id = ? AND workspace = ? AND channel = ?"
        let existingById = try await database.read { db in
            return try Row.fetchAll(db, sql: existingByIdSQL, arguments: [messageId, workspace, channel])
        }
        
        if let existingRow = existingById.first {
            let existingHash: String = existingRow["content_hash"] ?? ""
            let existingContent: String = existingRow["content"] ?? ""
            
            // Check if content changed (message edited)
            if existingHash != contentHash || existingContent != message.content {
                try await updateMessage(message, messageId: messageId, workspace: workspace, channel: channel)
                return .updated(messageId)
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
        
        // Generate and store vector embedding for the message content
        if !message.content.isEmpty {
            do {
                let embedding = try await generateEmbedding(for: message.content)
                try await insertEmbedding(messageId: messageId, embedding: embedding)
            } catch {
                Logger.shared.logDatabaseOperation("Failed to generate embedding for message \(messageId): \(error)")
                // Continue without embedding - not a critical failure
            }
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
    
    // MARK: - Search Methods
    
    public struct SlackMessageWithWorkspace {
        public let message: SlackMessage
        public let workspace: String
    }
    
    public func getMessageById(messageId: String) async throws -> SlackMessageWithWorkspace? {
        guard let db = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        return try await db.read { db in
            let sql = """
                SELECT id, workspace, timestamp, sender, content, channel, thread_ts,
                       mentions, attachment_names, version, edited_at
                FROM slack_messages
                WHERE id = ?
                LIMIT 1
            """
            
            if let row = try Row.fetchOne(db, sql: sql, arguments: [messageId]) {
                // Deserialize JSON fields
                let mentionsJSON: String = row["mentions"] ?? "[]"
                let attachmentsJSON: String = row["attachment_names"] ?? "[]"
                let mentions = try? self.deserializeStringArray(mentionsJSON)
                let attachments = try? self.deserializeStringArray(attachmentsJSON)
                
                // Create metadata if we have any
                let metadata: SlackMessage.MessageMetadata? = (mentions != nil || attachments != nil || row["version"] != nil || row["edited_at"] != nil) ? SlackMessage.MessageMetadata(
                    editedAt: row["edited_at"],
                    reactions: nil,  // Would need to fetch separately
                    mentions: mentions ?? [],
                    attachmentNames: attachments ?? [],
                    version: row["version"] ?? 1
                ) : nil
                
                return SlackMessageWithWorkspace(
                    message: SlackMessage(
                        id: row["id"],
                        timestamp: row["timestamp"],
                        sender: row["sender"],
                        content: row["content"],
                        channel: row["channel"],
                        threadId: row["thread_ts"],
                        messageType: .regular,
                        metadata: metadata
                    ),
                    workspace: row["workspace"]
                )
            }
            return nil
        }
    }
    
    public func getThreadMessages(threadId: String, limit: Int = 100) async throws -> [SlackMessageWithWorkspace] {
        guard let db = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        return try await db.read { db in
            let sql = """
                SELECT id, workspace, timestamp, sender, content, channel, thread_ts
                FROM slack_messages
                WHERE thread_ts = ?
                ORDER BY timestamp ASC
                LIMIT ?
            """
            
            let rows = try Row.fetchAll(db, sql: sql, arguments: [threadId, limit])
            
            return rows.map { row in
                SlackMessageWithWorkspace(
                    message: SlackMessage(
                        id: row["id"],
                        timestamp: row["timestamp"],
                        sender: row["sender"],
                        content: row["content"],
                        channel: row["channel"],
                        threadId: row["thread_ts"],
                        messageType: .regular,
                        metadata: nil
                    ),
                    workspace: row["workspace"]
                )
            }
        }
    }
    
    public func searchMessages(
        query: String,
        channels: [String]? = nil,
        users: [String]? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int = 20
    ) async throws -> [SlackMessageWithWorkspace] {
        guard let db = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        return try await db.read { db in
            var sql = "SELECT id, workspace, timestamp, sender, content, channel, thread_ts FROM slack_messages WHERE 1=1"
            var arguments: [DatabaseValueConvertible] = []
            
            // Add query filter (search in content)
            if !query.isEmpty {
                sql += " AND content LIKE ?"
                arguments.append("%\(query)%")
            }
            
            // Add channel filter
            if let channels = channels, !channels.isEmpty {
                let placeholders = Array(repeating: "?", count: channels.count).joined(separator: ",")
                sql += " AND channel IN (\(placeholders))"
                arguments.append(contentsOf: channels)
            }
            
            // Add user filter
            if let users = users, !users.isEmpty {
                let placeholders = Array(repeating: "?", count: users.count).joined(separator: ",")
                sql += " AND sender IN (\(placeholders))"
                arguments.append(contentsOf: users)
            }
            
            // Add date range filter
            if let startDate = startDate {
                sql += " AND timestamp >= ?"
                arguments.append(startDate)
            }
            
            if let endDate = endDate {
                sql += " AND timestamp <= ?"
                arguments.append(endDate)
            }
            
            // Order by timestamp descending and apply limit
            sql += " ORDER BY timestamp DESC LIMIT ?"
            arguments.append(limit)
            
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            
            // Return SlackMessageWithWorkspace objects
            return rows.map { row in
                SlackMessageWithWorkspace(
                    message: SlackMessage(
                        id: row["id"],
                        timestamp: row["timestamp"],
                        sender: row["sender"],
                        content: row["content"],
                        channel: row["channel"],
                        threadId: row["thread_ts"],
                        messageType: .regular,
                        metadata: nil
                    ),
                    workspace: row["workspace"]
                )
            }
        }
    }
    
    // MARK: - Vector Embedding Operations
    
    /// Generate vector embedding for text using NLEmbedding
    private func generateEmbedding(for text: String) async throws -> [Float] {
        // For now, create a simple hash-based embedding as a placeholder
        // TODO: Implement proper NLEmbedding when API is stable
        let hash = text.hash
        var embedding = Array(repeating: Float(0.0), count: 512)
        
        // Use hash to create a deterministic but varied embedding
        let hashBytes = withUnsafeBytes(of: hash) { Data($0) }
        for i in 0..<min(hashBytes.count, embedding.count) {
            embedding[i] = Float(hashBytes[i]) / 255.0
        }
        
        // Add some text-based features
        embedding[0] = Float(text.count) / 1000.0 // Normalized length
        embedding[1] = Float(text.split(separator: " ").count) / 100.0 // Word count
        
        return embedding
    }
    
    /// Store a vector embedding for a message
    public func insertEmbedding(messageId: String, embedding: [Float]) async throws {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        guard embedding.count == 512 else {
            throw SlackDatabaseError.insertFailed("Embedding must be 512 dimensions, got \(embedding.count)")
        }
        
        let sql = "INSERT INTO slack_message_embeddings (message_id, embedding) VALUES (?, ?)"
        
        try await database.write { db in
            // Convert Float array to Data for storage
            let embeddingData = Data(bytes: embedding, count: embedding.count * MemoryLayout<Float>.size)
            try db.execute(sql: sql, arguments: [messageId, embeddingData])
        }
        
        Logger.shared.logDatabaseOperation("Vector embedding stored for messageId: \(messageId)")
    }
    
    /// Get vector embedding for a message
    public func getEmbedding(messageId: String) async throws -> [Float]? {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        let sql = "SELECT embedding FROM slack_message_embeddings WHERE message_id = ?"
        
        return try await database.read { db in
            if let row = try Row.fetchOne(db, sql: sql, arguments: [messageId]),
               let embeddingData = row["embedding"] as? Data {
                // Convert Data back to [Float]
                let floatArray = embeddingData.withUnsafeBytes { bytes in
                    return Array(bytes.bindMemory(to: Float.self))
                }
                return floatArray
            }
            return nil
        }
    }
    
    /// Perform semantic search using vector similarity
    public func semanticSearch(embedding: [Float], limit: Int = 10) async throws -> [VectorSearchResult] {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        guard embedding.count == 512 else {
            throw SlackDatabaseError.queryFailed("Query embedding must be 512 dimensions, got \(embedding.count)")
        }
        
        // For now, implement basic similarity search
        // TODO: Use SQLiteVec's built-in similarity functions when available
        let sql = "SELECT message_id, embedding FROM slack_message_embeddings"
        
        return try await database.read { [self] db in
            let rows = try Row.fetchAll(db, sql: sql)
            var results: [VectorSearchResult] = []
            
            for row in rows {
                if let messageId = row["message_id"] as? String,
                   let embeddingData = row["embedding"] as? Data {
                    
                    let storedEmbedding = embeddingData.withUnsafeBytes { bytes in
                        return Array(bytes.bindMemory(to: Float.self))
                    }
                    
                    // Calculate cosine similarity
                    let similarity = self.cosineSimilarity(embedding, storedEmbedding)
                    let distance = 1.0 - similarity
                    
                    results.append(VectorSearchResult(
                        messageId: messageId,
                        distance: distance
                    ))
                }
            }
            
            // Sort by similarity (lowest distance = highest similarity) and limit
            return Array(results.sorted { $0.distance < $1.distance }.prefix(limit))
        }
    }
    
    /// Hybrid search combining semantic and keyword search
    public func hybridSearch(
        query: String,
        embedding: [Float],
        channels: [String]? = nil,
        users: [String]? = nil,
        limit: Int = 10
    ) async throws -> [SlackMessageWithWorkspace] {
        guard let database = database else {
            throw SlackDatabaseError.databaseNotOpen
        }
        
        // Get semantic search results
        let semanticResults = try await semanticSearch(embedding: embedding, limit: limit * 2)
        let semanticMessageIds = semanticResults.map { $0.messageId }
        
        return try await database.read { db in
            var sql = """
                SELECT DISTINCT sm.id, sm.workspace, sm.timestamp, sm.sender, sm.content, sm.channel, sm.thread_ts,
                       CASE WHEN sm.id IN (\(semanticMessageIds.isEmpty ? "NULL" : semanticMessageIds.map { _ in "?" }.joined(separator: ","))) THEN 1 ELSE 0 END as semantic_match
                FROM slack_messages sm
                WHERE 1=1
            """
            var arguments: [DatabaseValueConvertible] = semanticMessageIds.isEmpty ? [] : semanticMessageIds
            
            // Add text search filter
            if !query.isEmpty {
                if !semanticMessageIds.isEmpty {
                    sql += " AND (sm.content LIKE ? OR sm.id IN (\(semanticMessageIds.map { _ in "?" }.joined(separator: ","))))"
                    arguments.append("%\(query)%")
                    arguments.append(contentsOf: semanticMessageIds)
                } else {
                    sql += " AND sm.content LIKE ?"
                    arguments.append("%\(query)%")
                }
            }
            
            // Add channel filter
            if let channels = channels, !channels.isEmpty {
                let placeholders = Array(repeating: "?", count: channels.count).joined(separator: ",")
                sql += " AND sm.channel IN (\(placeholders))"
                arguments.append(contentsOf: channels)
            }
            
            // Add user filter
            if let users = users, !users.isEmpty {
                let placeholders = Array(repeating: "?", count: users.count).joined(separator: ",")
                sql += " AND sm.sender IN (\(placeholders))"
                arguments.append(contentsOf: users)
            }
            
            // Order by semantic match first, then by timestamp
            sql += " ORDER BY semantic_match DESC, sm.timestamp DESC LIMIT ?"
            arguments.append(limit)
            
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            
            return rows.map { row in
                SlackMessageWithWorkspace(
                    message: SlackMessage(
                        id: row["id"],
                        timestamp: row["timestamp"],
                        sender: row["sender"],
                        content: row["content"],
                        channel: row["channel"],
                        threadId: row["thread_ts"],
                        messageType: .regular,
                        metadata: nil
                    ),
                    workspace: row["workspace"]
                )
            }
        }
    }
    
    /// Convenience method for hybrid search with automatic embedding generation
    public func hybridSearchWithQuery(
        query: String,
        channels: [String]? = nil,
        users: [String]? = nil,
        limit: Int = 10
    ) async throws -> [SlackMessageWithWorkspace] {
        let embedding = try await generateEmbedding(for: query)
        return try await hybridSearch(
            query: query,
            embedding: embedding,
            channels: channels,
            users: users,
            limit: limit
        )
    }
    
    /// Calculate cosine similarity between two vectors
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count else { return 0.0 }
        
        let dotProduct = zip(a, b).map { Double($0) * Double($1) }.reduce(0, +)
        let magnitudeA = sqrt(a.map { Double($0) * Double($0) }.reduce(0, +))
        let magnitudeB = sqrt(b.map { Double($0) * Double($0) }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
}

// MARK: - Supporting Types

public struct VectorSearchResult {
    public let messageId: String
    public let distance: Double
    
    public init(messageId: String, distance: Double) {
        self.messageId = messageId
        self.distance = distance
    }
}

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