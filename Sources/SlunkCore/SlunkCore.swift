import Foundation
import NaturalLanguage
import GRDB
import SQLiteVec
import MCP

/// Core service for managing local semantic search with NLEmbedding and SQLiteVec
public actor SlunkCore {
    
    // MARK: - Properties
    
    private let dbQueue: DatabaseQueue           // GRDB for relational data
    private let vectorDB: SQLiteVec.Database     // SQLiteVec for embeddings
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)
    
    // MARK: - Initialization
    
    public init(databasePath: String = "slunk_data.db", vectorPath: String = "slunk_vectors.db") async throws {
        // Initialize GRDB for relational data
        self.dbQueue = try DatabaseQueue(path: databasePath)
        
        // Initialize SQLiteVec for vector storage
        try SQLiteVec.initialize()
        self.vectorDB = try SQLiteVec.Database(.file(vectorPath))
        
        try await setupDatabases()
    }
    
    // MARK: - Database Setup
    
    private func setupDatabases() async throws {
        // Setup relational tables
        try await dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS documents (
                    id INTEGER PRIMARY KEY,
                    title TEXT NOT NULL,
                    content TEXT NOT NULL,
                    category TEXT,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_documents_category ON documents(category)
            """)
            
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at)
            """)
        }
        
        // Setup vector table for NLEmbedding (512 dimensions)
        try await vectorDB.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS document_embeddings USING vec0(
                embedding float[512],
                document_id INTEGER
            )
        """)
    }
    
    // MARK: - Document Management
    
    /// Add a new document with automatic embedding generation
    public func addDocument(title: String, content: String, category: String? = nil) async throws -> Int {
        // Store relational data
        let documentId = try await dbQueue.write { db -> Int in
            try db.execute(
                sql: "INSERT INTO documents (title, content, category) VALUES (?, ?, ?)",
                arguments: [title, content, category]
            )
            return Int(db.lastInsertedRowID)
        }
        
        // Generate and store embedding
        guard let vector = embedding?.vector(for: content) else {
            throw SlunkError.embeddingGenerationFailed
        }
        
        try await vectorDB.execute("""
            INSERT INTO document_embeddings(embedding, document_id) 
            VALUES (?, ?)
        """, params: [vector, documentId])
        
        return documentId
    }
    
    /// Search for similar documents using semantic similarity
    public func searchSimilar(query: String, limit: Int = 10, category: String? = nil) async throws -> [SearchResult] {
        guard let queryVector = embedding?.vector(for: query) else {
            throw SlunkError.embeddingGenerationFailed
        }
        
        // Find similar vectors
        let vectorResults = try await vectorDB.query("""
            SELECT document_id, distance 
            FROM document_embeddings 
            WHERE embedding MATCH ? 
            ORDER BY distance 
            LIMIT ?
        """, params: [queryVector, limit])
        
        // Get document details from relational DB
        let documentIds = vectorResults.compactMap { $0["document_id"] as? Int }
        guard !documentIds.isEmpty else { return [] }
        
        let placeholders = Array(repeating: "?", count: documentIds.count).joined(separator: ",")
        var sql = """
            SELECT id, title, content, category, created_at 
            FROM documents 
            WHERE id IN (\(placeholders))
        """
        var arguments = StatementArguments(documentIds)
        
        // Add category filter if specified
        if let category = category {
            sql += " AND category = ?"
            arguments.append(category)
        }
        
        let documents = try await dbQueue.read { db in
            try Row.fetchAll(db, sql: sql, arguments: arguments)
        }
        
        // Combine results with similarity scores
        return vectorResults.compactMap { vectorRow in
            guard let docId = vectorRow["document_id"] as? Int,
                  let distance = vectorRow["distance"] as? Double,
                  let doc = documents.first(where: { $0["id"] == docId }) else {
                return nil
            }
            
            return SearchResult(
                id: docId,
                title: doc["title"],
                content: doc["content"],
                category: doc["category"],
                similarity: 1.0 - distance, // Convert distance to similarity
                createdAt: doc["created_at"]
            )
        }.sorted { $0.similarity > $1.similarity }
    }
    
    /// Get all documents with optional category filter
    public func getDocuments(category: String? = nil, limit: Int = 100) async throws -> [Document] {
        return try await dbQueue.read { db in
            var sql = "SELECT id, title, content, category, created_at FROM documents"
            var arguments = StatementArguments()
            
            if let category = category {
                sql += " WHERE category = ?"
                arguments.append(category)
            }
            
            sql += " ORDER BY created_at DESC LIMIT ?"
            arguments.append(limit)
            
            let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
            return rows.map { row in
                Document(
                    id: row["id"],
                    title: row["title"],
                    content: row["content"],
                    category: row["category"],
                    createdAt: row["created_at"]
                )
            }
        }
    }
    
    /// Delete a document and its embedding
    public func deleteDocument(id: Int) async throws {
        // Delete from relational database
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM documents WHERE id = ?", arguments: [id])
        }
        
        // Delete from vector database
        try await vectorDB.execute("DELETE FROM document_embeddings WHERE document_id = ?", params: [id])
    }
}

// MARK: - Data Models

public struct Document {
    public let id: Int
    public let title: String
    public let content: String
    public let category: String?
    public let createdAt: Date?
    
    public init(id: Int, title: String, content: String, category: String? = nil, createdAt: Date? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.createdAt = createdAt
    }
}

public struct SearchResult {
    public let id: Int
    public let title: String
    public let content: String
    public let category: String?
    public let similarity: Double
    public let createdAt: Date?
    
    public init(id: Int, title: String, content: String, category: String? = nil, similarity: Double, createdAt: Date? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.similarity = similarity
        self.createdAt = createdAt
    }
}

// MARK: - Errors

public enum SlunkError: Error, LocalizedError {
    case embeddingGenerationFailed
    case databaseError(String)
    case invalidInput(String)
    
    public var errorDescription: String? {
        switch self {
        case .embeddingGenerationFailed:
            return "Failed to generate text embedding"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}