import Foundation

// MARK: - Supporting Types

/// Simple in-memory mock database for testing
class MockDatabase {
    func execute(_ sql: String, params: [Any] = []) async throws {
        // Mock execution - just return success
    }
    
    func query(_ sql: String, params: [Any] = []) async throws -> [[String: Any]] {
        // Mock query - return empty results
        return []
    }
}

struct VectorSearchResult {
    let summaryId: String
    let distance: Double
    
    init(summaryId: String, distance: Double) {
        self.summaryId = summaryId
        self.distance = distance
    }
}

enum SQLiteVecSchemaError: Error {
    case invalidVectorDimensions(Int)
    case databaseNotOpen
    case insertFailed(String)
    case queryFailed(String)
    case invalidVectorData(String)
    case tableCreationFailed(String)
    case schemaVerificationFailed(String)
    case extensionNotLoaded(String)
    case databaseOpenFailed(String)
    case searchFailed(String)
    case deleteFailed(String)
}

/// Simplified SQLiteVecSchema for testing - uses in-memory storage
class SQLiteVecSchema {
    private var vectors: [String: [Float]] = [:]
    private var summaries: [String: TextSummary] = [:]
    
    // Mock database property for compatibility
    var database: MockDatabase? = MockDatabase()
    
    init() {
        // Simple initialization
    }
    
    convenience init(databasePath: String) {
        self.init()
    }
    
    convenience init(databaseURL: URL) {
        self.init()
    }
    
    func initializeDatabase() async throws {
        // Simple initialization - no actual database
    }
    
    func initializePersistentDatabase() async throws -> Bool {
        // For simplified version, just return success
        return true
    }
    
    func getVectorDimensions() throws -> Int {
        return 512
    }
    
    func verifyVectorIndexes() async throws -> Bool {
        return true
    }
    
    func insertVector(_ vector: [Float], summaryId: String) async throws {
        guard vector.count == 512 else {
            throw SQLiteVecSchemaError.invalidVectorDimensions(vector.count)
        }
        vectors[summaryId] = vector
    }
    
    func getVector(for summaryId: String) async throws -> [Float]? {
        return vectors[summaryId]
    }
    
    func searchSimilarVectors(_ queryVector: [Float], limit: Int) async throws -> [VectorSearchResult] {
        guard queryVector.count == 512 else {
            throw SQLiteVecSchemaError.invalidVectorDimensions(queryVector.count)
        }
        
        var results: [VectorSearchResult] = []
        
        for (summaryId, vector) in vectors {
            let distance = euclideanDistance(queryVector, vector)
            results.append(VectorSearchResult(summaryId: summaryId, distance: distance))
        }
        
        return Array(results.sorted { $0.distance < $1.distance }.prefix(limit))
    }
    
    func searchSimilarVectorsCosine(_ queryVector: [Float], limit: Int) async throws -> [VectorSearchResult] {
        guard queryVector.count == 512 else {
            throw SQLiteVecSchemaError.invalidVectorDimensions(queryVector.count)
        }
        
        var results: [VectorSearchResult] = []
        
        for (summaryId, vector) in vectors {
            let similarity = cosineSimilarity(queryVector, vector)
            let distance = 1.0 - similarity
            results.append(VectorSearchResult(summaryId: summaryId, distance: distance))
        }
        
        return Array(results.sorted { $0.distance < $1.distance }.prefix(limit))
    }
    
    private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count else { return Double.infinity }
        
        let sumOfSquares = zip(a, b).map { pow(Double($0.0 - $0.1), 2) }.reduce(0, +)
        return sqrt(sumOfSquares)
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count else { return 0.0 }
        
        let dotProduct = zip(a, b).map { Double($0.0) * Double($0.1) }.reduce(0, +)
        let magnitudeA = sqrt(a.map { Double($0) * Double($0) }.reduce(0, +))
        let magnitudeB = sqrt(b.map { Double($0) * Double($0) }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    func storeSummaryWithEmbedding(_ summary: TextSummary, embedding: [Float]) async throws {
        guard embedding.count == 512 else {
            throw SQLiteVecSchemaError.invalidVectorDimensions(embedding.count)
        }
        
        summaries[summary.id.uuidString] = summary
        vectors[summary.id.uuidString] = embedding
    }
    
    func querySummariesByDateRange(start: String, end: String) async throws -> [TextSummary] {
        return Array(summaries.values)
    }
    
    func getAllSummaries(limit: Int = 1000) async throws -> [TextSummary] {
        return Array(summaries.values.prefix(limit))
    }
    
    func querySummariesByKeywords(_ keywords: [String]) async throws -> [TextSummary] {
        // Simple keyword matching
        return summaries.values.filter { summary in
            keywords.allSatisfy { keyword in
                summary.keywords.contains { $0.lowercased().contains(keyword.lowercased()) }
            }
        }
    }
    
    func getTotalSummaryCount() async throws -> Int {
        return summaries.count
    }
    
    func getSummary(by id: String) async throws -> TextSummary? {
        return summaries[id]
    }
    
    func deleteSummary(by id: String) async throws {
        summaries.removeValue(forKey: id)
        vectors.removeValue(forKey: id)
    }
    
    func deleteVector(for summaryId: String) async throws {
        vectors.removeValue(forKey: summaryId)
    }
    
    func verifySQLiteVecLoaded() async throws {
        // For simplified schema, this always returns success
    }
    
    func getAllSummaries(limit: Int?) async throws -> [TextSummary] {
        let summaryArray = Array(summaries.values)
        if let limit = limit {
            return Array(summaryArray.prefix(limit))
        }
        return summaryArray
    }
}