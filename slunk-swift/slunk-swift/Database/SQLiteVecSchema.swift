import Foundation
import SQLiteVec

class SQLiteVecSchema {
    let databaseURL: URL
    var database: Database?
    
    // MARK: - Initialization
    
    init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }
    
    convenience init(databasePath: String) {
        self.init(databaseURL: URL(fileURLWithPath: databasePath))
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
        // Initialize SQLiteVec library first
        try SQLiteVec.initialize()
        try openDatabase()
        try await createVectorTable()
        try await createTextSummariesTable()
        try await createIndexes()
    }
    
    func initializePersistentDatabase() async throws -> Bool {
        // Create Application Support directory if needed
        let appSupportURL = try Self.getPersistentDatabaseURL()
        let directory = appSupportURL.deletingLastPathComponent()
        
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        try await initializeDatabase()
        return true
    }
    
    static func getPersistentDatabaseURL() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Slunk")
        return appDir.appendingPathComponent("vector_store.db")
    }
    
    private func openDatabase() throws {
        do {
            database = try Database(.uri(databaseURL.path))
        } catch {
            throw SQLiteVecSchemaError.databaseOpenFailed("Failed to open database: \(error.localizedDescription)")
        }
    }
    
    private func closeDatabase() {
        database = nil
    }
    
    func verifySQLiteVecLoaded() async throws {
        guard let database = database else {
            throw SQLiteVecSchemaError.databaseNotOpen
        }
        
        // Test SQLiteVec functionality by querying version
        do {
            _ = try await database.execute("SELECT vec_version()")
        } catch {
            throw SQLiteVecSchemaError.extensionNotLoaded("SQLiteVec extension not available: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Vector Table Management
    
    func createVectorTable() async throws {
        guard let database = database else {
            throw SQLiteVecSchemaError.databaseNotOpen
        }
        
        // Create vec0 virtual table with 512 dimensions
        let sql = """
            CREATE VIRTUAL TABLE IF NOT EXISTS summary_embeddings USING vec0(
                embedding float[512],
                summary_id text
            )
        """
        
        do {
            try await database.execute(sql)
        } catch {
            throw SQLiteVecSchemaError.tableCreationFailed("Failed to create vector table: \(error.localizedDescription)")
        }
    }
    
    func createTextSummariesTable() async throws {
        guard let database = database else {
            throw SQLiteVecSchemaError.databaseNotOpen
        }
        
        let sql = """
            CREATE TABLE IF NOT EXISTS text_summaries (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                summary TEXT NOT NULL,
                
                -- Enhanced metadata
                sender TEXT,
                timestamp DATETIME NOT NULL,
                source TEXT,
                keywords TEXT, -- JSON array
                category TEXT,
                tags TEXT, -- JSON array
                source_url TEXT,
                
                -- Computed fields
                word_count INTEGER,
                summary_word_count INTEGER,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                
                -- Temporal indexing
                date_only DATE GENERATED ALWAYS AS (DATE(timestamp)) STORED,
                month_year TEXT GENERATED ALWAYS AS (strftime('%Y-%m', timestamp)) STORED,
                day_of_week INTEGER GENERATED ALWAYS AS (strftime('%w', timestamp)) STORED
            )
        """
        
        do {
            try await database.execute(sql)
        } catch {
            throw SQLiteVecSchemaError.tableCreationFailed("Failed to create text summaries table: \(error.localizedDescription)")
        }
    }
    
    func createIndexes() async throws {
        guard let database = database else {
            throw SQLiteVecSchemaError.databaseNotOpen
        }
        
        let indexes = [
            "CREATE INDEX IF NOT EXISTS idx_summaries_timestamp ON text_summaries(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_summaries_date_only ON text_summaries(date_only)",
            "CREATE INDEX IF NOT EXISTS idx_summaries_sender ON text_summaries(sender)",
            "CREATE INDEX IF NOT EXISTS idx_summaries_source ON text_summaries(source)",
            "CREATE INDEX IF NOT EXISTS idx_summaries_category ON text_summaries(category)",
            "CREATE INDEX IF NOT EXISTS idx_summaries_month_year ON text_summaries(month_year)"
        ]
        
        for indexSQL in indexes {
            do {
                try await database.execute(indexSQL)
            } catch {
                throw SQLiteVecSchemaError.tableCreationFailed("Failed to create index: \(error.localizedDescription)")
            }
        }
    }
    
    func verifyVectorTableSchema() async throws {
        guard let database = database else {
            throw SQLiteVecSchemaError.databaseNotOpen
        }
        
        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name='summary_embeddings'"
        
        do {
            let result = try await database.query(sql)
            guard !result.isEmpty else {
                throw SQLiteVecSchemaError.schemaVerificationFailed("Vector table does not exist")
            }
        } catch {
            throw SQLiteVecSchemaError.schemaVerificationFailed("Failed to verify table schema: \(error.localizedDescription)")
        }
    }
    
    func getVectorDimensions() throws -> Int {
        // SQLiteVec vec0 tables with float[512] have 512 dimensions
        return 512
    }
    
    func verifyVectorIndexes() async throws -> Bool {
        // vec0 virtual tables automatically handle indexing for similarity search
        // Verify the table is accessible for vector operations
        try await verifyVectorTableSchema()
        return true
    }
    
    // MARK: - Vector Operations
    
    func insertVector(_ vector: [Float], summaryId: String) async throws {
        guard vector.count == 512 else {
            throw SQLiteVecSchemaError.invalidVectorDimensions(vector.count)
        }
        
        guard let database = database else {
            throw SQLiteVecSchemaError.databaseNotOpen
        }
        
        let sql = "INSERT INTO summary_embeddings (embedding, summary_id) VALUES (?, ?)"
        
        do {
            try await database.execute(sql, params: [vector, summaryId])
        } catch {
            throw SQLiteVecSchemaError.insertFailed("Failed to insert vector: \(error.localizedDescription)")
        }
    }
    
    func getVector(for summaryId: String) async throws -> [Float]? {
        guard let database = database else {
            throw SQLiteVecSchemaError.databaseNotOpen
        }
        
        let sql = "SELECT embedding FROM summary_embeddings WHERE summary_id = ?"
        
        do {
            let results = try await database.query(sql, params: [summaryId])
            guard let firstResult = results.first,
                  let embedding = firstResult["embedding"] as? [Float] else {
                return nil
            }
            
            guard embedding.count == 512 else {
                throw SQLiteVecSchemaError.invalidVectorData("Invalid vector dimensions: \(embedding.count)")
            }
            
            return embedding
            
        } catch {
            throw SQLiteVecSchemaError.queryFailed("Failed to query vector: \(error.localizedDescription)")
        }
    }
    
    func deleteVector(for summaryId: String) async throws {
        guard let database = database else {
            throw SQLiteVecSchemaError.databaseNotOpen
        }
        
        let sql = "DELETE FROM summary_embeddings WHERE summary_id = ?"
        
        do {
            try await database.execute(sql, params: [summaryId])
        } catch {
            throw SQLiteVecSchemaError.deleteFailed("Failed to delete vector: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Similarity Search
    
    func searchSimilarVectors(_ queryVector: [Float], limit: Int) async throws -> [VectorSearchResult] {
        guard queryVector.count == 512 else {
            throw SQLiteVecSchemaError.invalidVectorDimensions(queryVector.count)
        }
        
        guard let database = database else {
            throw SQLiteVecSchemaError.databaseNotOpen
        }
        
        let sql = """
            SELECT summary_id, distance
            FROM summary_embeddings
            WHERE embedding MATCH ? AND k = ?
            ORDER BY distance
        """
        
        do {
            let results = try await database.query(sql, params: [queryVector, limit])
            
            return results.compactMap { row in
                guard let summaryId = row["summary_id"] as? String,
                      let distance = row["distance"] as? Double else {
                    return nil
                }
                return VectorSearchResult(summaryId: summaryId, distance: distance)
            }
            
        } catch {
            throw SQLiteVecSchemaError.searchFailed("Failed to search vectors: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Enhanced Data Operations
    
    func storeSummaryWithEmbedding(_ summary: TextSummary, embedding: [Float]) async throws {
        guard embedding.count == 512 else {
            throw SQLiteVecSchemaError.invalidVectorDimensions(embedding.count)
        }
        
        guard let database = database else {
            throw SQLiteVecSchemaError.databaseNotOpen
        }
        
        // Store text summary first
        let keywordsJSON = try JSONSerialization.data(withJSONObject: summary.keywords)
        let keywordsString = String(data: keywordsJSON, encoding: .utf8) ?? "[]"
        
        let tagsJSON = summary.tags != nil ? try JSONSerialization.data(withJSONObject: summary.tags!) : Data("[]".utf8)
        let tagsString = String(data: tagsJSON, encoding: .utf8) ?? "[]"
        
        let textSQL = """
            INSERT INTO text_summaries (
                id, title, content, summary, sender, timestamp, source, keywords,
                category, tags, source_url, word_count, summary_word_count
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        try await database.execute(textSQL, params: [
            summary.id.uuidString,
            summary.title,
            summary.content,
            summary.summary,
            summary.sender,
            summary.timestamp,
            summary.source,
            keywordsString,
            summary.category,
            tagsString,
            summary.sourceURL,
            summary.wordCount,
            summary.summaryWordCount
        ])
        
        // Store vector embedding
        try await insertVector(embedding, summaryId: summary.id.uuidString)
    }
    
    func querySummariesByDateRange(start: String, end: String) async throws -> [TextSummary] {
        guard let database = database else {
            throw SQLiteVecSchemaError.databaseNotOpen
        }
        
        let sql = """
            SELECT * FROM text_summaries
            WHERE date_only BETWEEN ? AND ?
            ORDER BY timestamp DESC
        """
        
        do {
            let results = try await database.query(sql, params: [start, end])
            return try results.map { try parseTextSummary(from: $0) }
        } catch {
            throw SQLiteVecSchemaError.queryFailed("Failed to query by date range: \(error.localizedDescription)")
        }
    }
    
    func querySummariesByKeywords(_ keywords: [String]) async throws -> [TextSummary] {
        guard let database = database else {
            throw SQLiteVecSchemaError.databaseNotOpen
        }
        
        // Use JSON_EXTRACT to search in keywords array
        let keywordConditions = keywords.map { _ in "keywords LIKE ?" }.joined(separator: " OR ")
        let sql = """
            SELECT * FROM text_summaries
            WHERE \(keywordConditions)
            ORDER BY timestamp DESC
        """
        
        let params = keywords.map { "%\"\($0)\"%"}
        
        do {
            let results = try await database.query(sql, params: params)
            return try results.map { try parseTextSummary(from: $0) }
        } catch {
            throw SQLiteVecSchemaError.queryFailed("Failed to query by keywords: \(error.localizedDescription)")
        }
    }
    
    private func parseTextSummary(from row: [String: Any]) throws -> TextSummary {
        guard let idString = row["id"] as? String,
              let title = row["title"] as? String,
              let content = row["content"] as? String,
              let summary = row["summary"] as? String,
              let wordCount = row["word_count"] as? Int,
              let summaryWordCount = row["summary_word_count"] as? Int else {
            throw SQLiteVecSchemaError.queryFailed("Invalid row data - missing required fields")
        }
        
        // Parse timestamp from string if needed
        let timestamp: Date
        if let timestampDate = row["timestamp"] as? Date {
            timestamp = timestampDate
        } else if let timestampString = row["timestamp"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            timestamp = formatter.date(from: timestampString) ?? Date()
        } else {
            timestamp = Date()
        }
        
        let sender = row["sender"] as? String
        let source = row["source"] as? String
        let category = row["category"] as? String
        let sourceURL = row["source_url"] as? String
        
        // Parse JSON arrays
        let keywordsString = row["keywords"] as? String ?? "[]"
        let keywords = try parseJSONStringArray(keywordsString)
        
        let tagsString = row["tags"] as? String ?? "[]"
        let tags = try parseJSONStringArray(tagsString)
        
        // Create TextSummary with the basic initializer
        return TextSummary(
            title: title,
            content: content,
            summary: summary,
            sender: sender,
            timestamp: timestamp,
            source: source,
            keywords: keywords,
            category: category,
            tags: tags.isEmpty ? nil : tags,
            sourceURL: sourceURL
        )
    }
    
    private func parseJSONStringArray(_ jsonString: String) throws -> [String] {
        guard let data = jsonString.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return array
    }
}

// MARK: - Error Types

enum SQLiteVecSchemaError: Error, Equatable {
    case databaseNotOpen
    case databaseOpenFailed(String)
    case extensionLoadFailed(String)
    case extensionNotLoaded(String)
    case tableCreationFailed(String)
    case schemaVerificationFailed(String)
    case invalidVectorDimensions(Int)
    case invalidVectorData(String)
    case insertFailed(String)
    case queryFailed(String)
    case deleteFailed(String)
    case searchFailed(String)
}

extension SQLiteVecSchemaError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .databaseNotOpen:
            return "Database is not open"
        case .databaseOpenFailed(let message):
            return "Failed to open database: \(message)"
        case .extensionLoadFailed(let message):
            return "Failed to load SQLiteVec extension: \(message)"
        case .extensionNotLoaded(let message):
            return "SQLiteVec extension not loaded: \(message)"
        case .tableCreationFailed(let message):
            return "Failed to create vector table: \(message)"
        case .schemaVerificationFailed(let message):
            return "Schema verification failed: \(message)"
        case .invalidVectorDimensions(let dimensions):
            return "Invalid vector dimensions: \(dimensions), expected 512"
        case .invalidVectorData(let message):
            return "Invalid vector data: \(message)"
        case .insertFailed(let message):
            return "Vector insertion failed: \(message)"
        case .queryFailed(let message):
            return "Vector query failed: \(message)"
        case .deleteFailed(let message):
            return "Vector deletion failed: \(message)"
        case .searchFailed(let message):
            return "Vector search failed: \(message)"
        }
    }
}

// MARK: - Result Types

struct VectorSearchResult {
    let summaryId: String
    let distance: Double
}