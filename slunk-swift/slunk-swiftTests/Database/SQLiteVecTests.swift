import XCTest
import SQLiteVec
import Foundation
@testable import slunk_swift

final class SQLiteVecTests: XCTestCase {
    
    var sqliteVecSchema: SQLiteVecSchema!
    var tempDatabaseURL: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary database file for testing
        let tempDir = FileManager.default.temporaryDirectory
        tempDatabaseURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).db")
        
        sqliteVecSchema = SQLiteVecSchema(databaseURL: tempDatabaseURL)
    }
    
    override func tearDown() {
        sqliteVecSchema = nil
        
        // Clean up temporary database file
        if let tempURL = tempDatabaseURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        tempDatabaseURL = nil
        
        super.tearDown()
    }
    
    func testSQLiteVecInitialization() async throws {
        // Should initialize SQLiteVec extension
        try await sqliteVecSchema.initializeDatabase()
        
        // Should verify SQLiteVec is loaded correctly
        try await sqliteVecSchema.verifySQLiteVecLoaded()
        
        // Should handle re-initialization gracefully
        try await sqliteVecSchema.initializeDatabase()
    }
    
    func testSQLiteVecLoadingFailure() throws {
        // Should handle SQLiteVec loading failures
        // Create schema with invalid path to test error handling
        let invalidURL = URL(fileURLWithPath: "/invalid/path/test.db")
        let invalidSchema = SQLiteVecSchema(databaseURL: invalidURL)
        
        XCTAssertThrowsError(try invalidSchema.openDatabase()) { error in
            XCTAssertTrue(error is SQLiteVecSchemaError)
        }
    }
    
    func testVectorTableCreation() async throws {
        // Initialize database first
        try await sqliteVecSchema.initializeDatabase()
        
        // Should create vec0 virtual table (already done in initialize)
        try await sqliteVecSchema.createVectorTable()
        
        // Should verify table exists with correct schema
        try await sqliteVecSchema.verifyVectorTableSchema()
        
        // Should handle table recreation gracefully
        try await sqliteVecSchema.createVectorTable()
    }
    
    func testVectorTableDimensions() throws {
        // Should set correct embedding dimensions (512)
        let dimensions = try sqliteVecSchema.getVectorDimensions()
        XCTAssertEqual(dimensions, 512, "Vector table should have 512 dimensions")
    }
    
    func testVectorTableIndexes() async throws {
        // Initialize and create table
        try await sqliteVecSchema.initializeDatabase()
        
        // Should create with proper indexes
        let hasIndexes = try await sqliteVecSchema.verifyVectorIndexes()
        XCTAssertTrue(hasIndexes, "Vector table should have proper indexes")
    }
    
    func testSQLiteVecQueries() async throws {
        // Initialize and create table
        try await sqliteVecSchema.initializeDatabase()
        
        // Should insert vectors successfully
        let testVector: [Float] = Array(repeating: 0.1, count: 512)
        let summaryId = "test-summary-123"
        
        try await sqliteVecSchema.insertVector(testVector, summaryId: summaryId)
        
        // Should verify vector was inserted
        let insertedVector = try await sqliteVecSchema.getVector(for: summaryId)
        XCTAssertNotNil(insertedVector, "Should retrieve inserted vector")
        XCTAssertEqual(insertedVector?.count, 512, "Retrieved vector should have correct dimensions")
    }
    
    func testVectorSimilaritySearch() async throws {
        // Initialize and create table
        try await sqliteVecSchema.initializeDatabase()
        
        // Insert test vectors
        let vector1: [Float] = Array(0..<512).map { Float($0) / 512.0 }
        let vector2: [Float] = Array(0..<512).map { Float($0 + 100) / 512.0 }
        let vector3: [Float] = Array(0..<512).map { Float($0) / 512.0 } // Same as vector1
        
        try await sqliteVecSchema.insertVector(vector1, summaryId: "summary-1")
        try await sqliteVecSchema.insertVector(vector2, summaryId: "summary-2")
        try await sqliteVecSchema.insertVector(vector3, summaryId: "summary-3")
        
        // Should perform similarity searches
        let queryVector = vector1
        let results = try await sqliteVecSchema.searchSimilarVectors(queryVector, limit: 2)
        
        XCTAssertNotNil(results, "Should return similarity search results")
        XCTAssertEqual(results.count, 2, "Should return requested number of results")
        
        // Should return distance scores correctly
        for result in results {
            XCTAssertGreaterThanOrEqual(result.distance, 0.0, "Distance should be non-negative")
            XCTAssertFalse(result.summaryId.isEmpty, "Result should include summary ID")
        }
        
        // First result should be most similar (lowest distance)
        if results.count >= 2 {
            XCTAssertLessThanOrEqual(results[0].distance, results[1].distance, "Results should be ordered by distance")
        }
    }
    
    func testVectorOperationsWithDifferentDimensions() async throws {
        // Initialize and create table
        try await sqliteVecSchema.initializeDatabase()
        
        // Should reject vectors with wrong dimensions
        let wrongDimensionVector: [Float] = Array(repeating: 0.1, count: 256) // Wrong size
        
        do {
            try await sqliteVecSchema.insertVector(wrongDimensionVector, summaryId: "invalid")
            XCTFail("Should have thrown an error for wrong dimension vector")
        } catch {
            XCTAssertTrue(error is SQLiteVecSchemaError)
        }
    }
    
    func testVectorDeletion() async throws {
        // Initialize and create table
        try await sqliteVecSchema.initializeDatabase()
        
        // Insert test vector
        let testVector: [Float] = Array(repeating: 0.1, count: 512)
        let summaryId = "test-delete-123"
        
        try await sqliteVecSchema.insertVector(testVector, summaryId: summaryId)
        
        // Verify vector exists
        let retrievedVector = try await sqliteVecSchema.getVector(for: summaryId)
        XCTAssertNotNil(retrievedVector, "Vector should exist before deletion")
        
        // Delete vector
        try await sqliteVecSchema.deleteVector(for: summaryId)
        
        // Verify vector is deleted
        let deletedVector = try await sqliteVecSchema.getVector(for: summaryId)
        XCTAssertNil(deletedVector, "Vector should be deleted")
    }
    
    func testDatabasePerformance() async throws {
        // Initialize and create table
        try await sqliteVecSchema.initializeDatabase()
        
        // Insert multiple vectors for performance testing
        let vectorCount = 50 // Reduced for test performance
        var vectors: [(vector: [Float], id: String)] = []
        
        for i in 0..<vectorCount {
            let vector: [Float] = Array(0..<512).map { _ in Float.random(in: -1...1) }
            let summaryId = "perf-test-\(i)"
            vectors.append((vector, summaryId))
        }
        
        // Measure insertion time
        let insertStart = Date()
        for (vector, summaryId) in vectors {
            try await sqliteVecSchema.insertVector(vector, summaryId: summaryId)
        }
        let insertTime = Date().timeIntervalSince(insertStart)
        
        // Should complete insertions in reasonable time (< 10 seconds for 50 vectors)
        XCTAssertLessThan(insertTime, 10.0, "50 vector insertions should complete in under 10 seconds")
        
        // Measure search time
        let queryVector = vectors[0].vector
        let searchStart = Date()
        let results = try await sqliteVecSchema.searchSimilarVectors(queryVector, limit: 10)
        let searchTime = Date().timeIntervalSince(searchStart)
        
        // Should complete search in reasonable time (< 5 seconds)
        XCTAssertLessThan(searchTime, 5.0, "Vector search should complete in under 5 seconds")
        XCTAssertNotNil(results, "Search should return results")
        XCTAssertLessThanOrEqual(results.count, 10, "Should return at most requested number of results")
    }
}

// Helper extension to expose openDatabase for testing
extension SQLiteVecSchema {
    func openDatabase() throws {
        do {
            database = try Database(.uri(databaseURL.path))
        } catch {
            throw SQLiteVecSchemaError.databaseOpenFailed("Failed to open database: \(error.localizedDescription)")
        }
    }
}