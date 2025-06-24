import Foundation
import SQLiteVec

class SQLiteVecSchema {
    let databaseURL: URL
    var database: Database?
    
    // MARK: - Initialization
    
    init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Setup
    
    func initializeDatabase() async throws {
        try openDatabase()
        try await createVectorTable()
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