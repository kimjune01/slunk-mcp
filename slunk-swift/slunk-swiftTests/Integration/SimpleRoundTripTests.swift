import XCTest
import Foundation
import SQLiteVec
@testable import slunk_swift

final class SimpleRoundTripTests: XCTestCase {
    
    func testBasicRoundTrip() async throws {
        // Initialize SQLiteVec
        try SQLiteVec.initialize()
        
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("simple_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // 1. Create TextSummary
        let summary = TextSummary(
            title: "Test Title",
            content: "This is test content for our round trip test",
            summary: "Test summary for verification"
        )
        
        XCTAssertEqual(summary.title, "Test Title")
        XCTAssertEqual(summary.wordCount, 10) // "This is test content for our round trip test"
        XCTAssertEqual(summary.summaryWordCount, 4) // "Test summary for verification"
        
        // 2. Generate embedding
        let embeddingService = EmbeddingService()
        guard let embedding = embeddingService.generateEmbedding(for: summary.summary) else {
            XCTFail("Failed to generate embedding")
            return
        }
        
        XCTAssertEqual(embedding.count, 512, "Should generate 512-dimensional embedding")
        
        // 3. Store in vector database
        let vectorStore = SQLiteVecSchema(databaseURL: tempURL)
        try await vectorStore.initializeDatabase()
        
        try await vectorStore.insertVector(embedding, summaryId: summary.id.uuidString)
        
        // 4. Retrieve and verify
        let retrievedVector = try await vectorStore.getVector(for: summary.id.uuidString)
        XCTAssertNotNil(retrievedVector, "Should retrieve stored vector")
        XCTAssertEqual(retrievedVector?.count, 512, "Retrieved vector should have correct dimensions")
        
        // Verify vector values match
        if let retrieved = retrievedVector {
            for (original, stored) in zip(embedding, retrieved) {
                XCTAssertEqual(original, stored, accuracy: 0.0001, "Vector values should match")
            }
        }
        
        // 5. Test similarity search
        let searchResults = try await vectorStore.searchSimilarVectors(embedding, limit: 1)
        XCTAssertEqual(searchResults.count, 1, "Should find one result")
        XCTAssertEqual(searchResults[0].summaryId, summary.id.uuidString, "Should find the correct summary")
        XCTAssertLessThan(searchResults[0].distance, 0.1, "Distance should be very small for identical vectors")
        
        print("✅ Simple round-trip test passed!")
        print("📝 Created TextSummary with \(summary.wordCount) words")
        print("🧠 Generated \(embedding.count)-dimensional embedding")
        print("💾 Stored and retrieved vector successfully")
        print("🔍 Found summary with distance: \(searchResults[0].distance)")
    }
    
    func testTwoSummaryComparison() async throws {
        // Initialize SQLiteVec
        try SQLiteVec.initialize()
        
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("comparison_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // Create two different summaries
        let summary1 = TextSummary(
            title: "Programming in Swift",
            content: "Swift is a programming language for iOS development",
            summary: "Swift programming for mobile apps"
        )
        
        let summary2 = TextSummary(
            title: "Cooking Recipes",
            content: "How to make delicious pasta with tomato sauce",
            summary: "Pasta cooking recipe guide"
        )
        
        // Generate embeddings
        let embeddingService = EmbeddingService()
        guard let embedding1 = embeddingService.generateEmbedding(for: summary1.summary),
              let embedding2 = embeddingService.generateEmbedding(for: summary2.summary) else {
            XCTFail("Failed to generate embeddings")
            return
        }
        
        // Store both vectors
        let vectorStore = SQLiteVecSchema(databaseURL: tempURL)
        try await vectorStore.initializeDatabase()
        
        try await vectorStore.insertVector(embedding1, summaryId: summary1.id.uuidString)
        try await vectorStore.insertVector(embedding2, summaryId: summary2.id.uuidString)
        
        // Search for programming-related content
        guard let programmingQuery = embeddingService.generateEmbedding(for: "iOS mobile app development") else {
            XCTFail("Failed to generate query embedding")
            return
        }
        
        let results = try await vectorStore.searchSimilarVectors(programmingQuery, limit: 2)
        XCTAssertEqual(results.count, 2, "Should find both summaries")
        
        // Programming summary should be more similar (lower distance)
        let firstResult = results[0]
        XCTAssertEqual(firstResult.summaryId, summary1.id.uuidString, "Programming summary should be first")
        
        // Verify results are ordered by distance
        XCTAssertLessThan(results[0].distance, results[1].distance, "Results should be ordered by similarity")
        
        print("✅ Two-summary comparison test passed!")
        print("🥇 Programming summary distance: \(results[0].distance)")
        print("🥈 Cooking summary distance: \(results[1].distance)")
        print("📊 Semantic similarity ranking working correctly")
    }
}