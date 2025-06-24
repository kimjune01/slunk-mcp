import XCTest
import Foundation
import SQLiteVec
@testable import slunk_swift

final class RoundTripIntegrationTests: XCTestCase {
    
    var embeddingService: EmbeddingService!
    var sqliteVecSchema: SQLiteVecSchema!
    var tempDatabaseURL: URL!
    
    override func setUp() {
        super.setUp()
        
        // Initialize SQLiteVec library
        try! SQLiteVec.initialize()
        
        // Initialize embedding service
        embeddingService = EmbeddingService()
        
        // Create temporary database for testing
        let tempDir = FileManager.default.temporaryDirectory
        tempDatabaseURL = tempDir.appendingPathComponent("roundtrip_test_\(UUID().uuidString).db")
        
        // Initialize vector database
        sqliteVecSchema = SQLiteVecSchema(databaseURL: tempDatabaseURL)
    }
    
    override func tearDown() {
        embeddingService = nil
        sqliteVecSchema = nil
        
        // Clean up temporary database file
        if let tempURL = tempDatabaseURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        tempDatabaseURL = nil
        
        super.tearDown()
    }
    
    func testFullRoundTripWorkflow() async throws {
        // MARK: - Setup Database
        try await sqliteVecSchema.initializeDatabase()
        
        // MARK: - Create Test Summaries
        let summaries = [
            TextSummary(
                title: "Swift Programming Guide",
                content: "Swift is a powerful and intuitive programming language for iOS, macOS, watchOS, and tvOS app development. Swift code is safe by design and produces software that runs lightning-fast.",
                summary: "Swift is Apple's programming language for app development across all platforms.",
                category: "Programming",
                tags: ["swift", "ios", "apple", "programming"],
                sourceURL: "https://swift.org"
            ),
            TextSummary(
                title: "Machine Learning Basics",
                content: "Machine learning is a method of data analysis that automates analytical model building. It is a branch of artificial intelligence based on the idea that systems can learn from data.",
                summary: "Machine learning automates model building using data analysis techniques.",
                category: "AI",
                tags: ["ml", "ai", "data", "analysis"],
                sourceURL: "https://example.com/ml"
            ),
            TextSummary(
                title: "Database Design Principles",
                content: "Good database design is essential for creating efficient, scalable, and maintainable applications. Normalization, indexing, and proper relationships are key concepts.",
                summary: "Database design focuses on efficiency, scalability, and maintainability.",
                category: "Database",
                tags: ["database", "design", "sql", "normalization"],
                sourceURL: "https://example.com/db"
            )
        ]
        
        // Validate all summaries
        for summary in summaries {
            XCTAssertNoThrow(try TextSummary.validate(
                title: summary.title,
                content: summary.content,
                summary: summary.summary,
                category: summary.category,
                tags: summary.tags,
                sourceURL: summary.sourceURL
            ), "Summary should pass validation")
        }
        
        // MARK: - Generate Embeddings and Store Vectors
        var storedSummaries: [(summary: TextSummary, embedding: [Float])] = []
        
        for summary in summaries {
            // Generate embedding from summary text
            guard let embedding = embeddingService.generateEmbedding(for: summary.summary) else {
                XCTFail("Failed to generate embedding for summary: \(summary.title)")
                continue
            }
            
            // Validate embedding dimensions
            XCTAssertEqual(embedding.count, 512, "Embedding should have 512 dimensions")
            
            // Store vector in database
            try await sqliteVecSchema.insertVector(embedding, summaryId: summary.id.uuidString)
            
            // Verify vector was stored
            let retrievedVector = try await sqliteVecSchema.getVector(for: summary.id.uuidString)
            XCTAssertNotNil(retrievedVector, "Should retrieve stored vector")
            XCTAssertEqual(retrievedVector?.count, 512, "Retrieved vector should have correct dimensions")
            
            // Verify vector values match (with small floating point tolerance)
            if let retrieved = retrievedVector {
                for (original, stored) in zip(embedding, retrieved) {
                    XCTAssertEqual(original, stored, accuracy: 0.0001, "Vector values should match within tolerance")
                }
            }
            
            storedSummaries.append((summary, embedding))
        }
        
        XCTAssertEqual(storedSummaries.count, 3, "Should have stored all 3 summaries")
        
        // MARK: - Test Similarity Search
        
        // Search for programming-related content using Swift summary
        let swiftSummary = storedSummaries[0].summary
        let swiftEmbedding = storedSummaries[0].embedding
        
        let programmingQuery = "iOS app development with Swift programming language"
        guard let queryEmbedding = embeddingService.generateEmbedding(for: programmingQuery) else {
            XCTFail("Failed to generate embedding for search query")
            return
        }
        
        // Perform similarity search
        let searchResults = try await sqliteVecSchema.searchSimilarVectors(queryEmbedding, limit: 3)
        
        XCTAssertGreaterThan(searchResults.count, 0, "Should return search results")
        XCTAssertLessThanOrEqual(searchResults.count, 3, "Should not exceed limit")
        
        // Verify results are ordered by distance (closest first)
        for i in 1..<searchResults.count {
            XCTAssertLessThanOrEqual(
                searchResults[i-1].distance,
                searchResults[i].distance,
                "Results should be ordered by distance (ascending)"
            )
        }
        
        // The Swift summary should be the most similar result for programming query
        let mostSimilarId = searchResults.first?.summaryId
        XCTAssertEqual(mostSimilarId, swiftSummary.id.uuidString, "Swift summary should be most similar to programming query")
        
        // MARK: - Test Different Query Types
        
        // Search for AI/ML content
        let aiQuery = "artificial intelligence and machine learning algorithms"
        guard let aiQueryEmbedding = embeddingService.generateEmbedding(for: aiQuery) else {
            XCTFail("Failed to generate embedding for AI query")
            return
        }
        
        let aiResults = try await sqliteVecSchema.searchSimilarVectors(aiQueryEmbedding, limit: 2)
        XCTAssertGreaterThan(aiResults.count, 0, "Should find AI-related results")
        
        // ML summary should be among top results for AI query
        let mlSummaryId = storedSummaries[1].summary.id.uuidString
        let hasMLInResults = aiResults.contains { $0.summaryId == mlSummaryId }
        XCTAssertTrue(hasMLInResults, "ML summary should be found in AI search results")
        
        // MARK: - Test Data Consistency
        
        // Verify all stored summaries can be retrieved
        for (summary, _) in storedSummaries {
            let retrievedVector = try await sqliteVecSchema.getVector(for: summary.id.uuidString)
            XCTAssertNotNil(retrievedVector, "Should be able to retrieve vector for summary: \(summary.title)")
        }
        
        // MARK: - Test Edge Cases
        
        // Search with empty results (very specific query)
        let specificQuery = "quantum computing blockchain cryptocurrency metaverse"
        guard let specificEmbedding = embeddingService.generateEmbedding(for: specificQuery) else {
            XCTFail("Failed to generate embedding for specific query")
            return
        }
        
        let specificResults = try await sqliteVecSchema.searchSimilarVectors(specificEmbedding, limit: 1)
        // Should still return results, but with higher distances
        if !specificResults.isEmpty {
            XCTAssertGreaterThan(specificResults[0].distance, 0.5, "Unrelated query should have higher distance")
        }
        
        // MARK: - Test Deletion and Cleanup
        
        // Delete one summary and verify it's gone
        let summaryToDelete = storedSummaries[1].summary
        try await sqliteVecSchema.deleteVector(for: summaryToDelete.id.uuidString)
        
        let deletedVector = try await sqliteVecSchema.getVector(for: summaryToDelete.id.uuidString)
        XCTAssertNil(deletedVector, "Deleted vector should not be retrievable")
        
        // Verify other summaries are still there
        let remainingVector = try await sqliteVecSchema.getVector(for: storedSummaries[0].summary.id.uuidString)
        XCTAssertNotNil(remainingVector, "Other vectors should remain after deletion")
        
        // Search should now return fewer results
        let postDeleteResults = try await sqliteVecSchema.searchSimilarVectors(queryEmbedding, limit: 3)
        XCTAssertEqual(postDeleteResults.count, 2, "Should return one fewer result after deletion")
        
        print("✅ Round-trip integration test completed successfully!")
        print("📊 Test Summary:")
        print("   - Created and validated 3 TextSummary objects")
        print("   - Generated 512-dimensional embeddings for each")
        print("   - Stored vectors in SQLiteVec database")
        print("   - Performed similarity searches with different queries")
        print("   - Verified semantic similarity ranking")
        print("   - Tested data consistency and edge cases")
        print("   - Verified deletion and cleanup operations")
    }
    
    func testEmbeddingConsistencyAcrossRoundTrips() async throws {
        // Test that the same text always produces the same embedding
        try await sqliteVecSchema.initializeDatabase()
        
        let testText = "This is a test text for embedding consistency verification"
        let testSummary = TextSummary(
            title: "Consistency Test",
            content: testText,
            summary: testText
        )
        
        // Generate embedding multiple times
        let embedding1 = embeddingService.generateEmbedding(for: testText)
        let embedding2 = embeddingService.generateEmbedding(for: testText)
        let embedding3 = embeddingService.generateEmbedding(for: testText)
        
        XCTAssertNotNil(embedding1)
        XCTAssertNotNil(embedding2)
        XCTAssertNotNil(embedding3)
        
        // Verify embeddings are identical
        if let emb1 = embedding1, let emb2 = embedding2, let emb3 = embedding3 {
            XCTAssertEqual(emb1.count, emb2.count)
            XCTAssertEqual(emb2.count, emb3.count)
            
            for i in 0..<emb1.count {
                XCTAssertEqual(emb1[i], emb2[i], accuracy: 0.0001, "Embeddings should be identical")
                XCTAssertEqual(emb2[i], emb3[i], accuracy: 0.0001, "Embeddings should be identical")
            }
            
            // Store and retrieve to test database consistency
            try await sqliteVecSchema.insertVector(emb1, summaryId: testSummary.id.uuidString)
            let retrievedEmbedding = try await sqliteVecSchema.getVector(for: testSummary.id.uuidString)
            
            XCTAssertNotNil(retrievedEmbedding)
            if let retrieved = retrievedEmbedding {
                XCTAssertEqual(retrieved.count, emb1.count)
                for i in 0..<emb1.count {
                    XCTAssertEqual(emb1[i], retrieved[i], accuracy: 0.0001, "Stored and retrieved embeddings should match")
                }
            }
        }
    }
    
    func testPerformanceRoundTrip() async throws {
        // Performance test for the full workflow
        try await sqliteVecSchema.initializeDatabase()
        
        let testSummaries = (1...20).map { i in
            TextSummary(
                title: "Performance Test Summary \(i)",
                content: "This is test content number \(i) for performance testing of the full round-trip workflow. It contains enough text to generate meaningful embeddings.",
                summary: "Performance test summary \(i) for workflow testing."
            )
        }
        
        // Measure full round-trip time
        let startTime = Date()
        
        for summary in testSummaries {
            // Generate embedding
            guard let embedding = embeddingService.generateEmbedding(for: summary.summary) else {
                XCTFail("Failed to generate embedding")
                continue
            }
            
            // Store in database
            try await sqliteVecSchema.insertVector(embedding, summaryId: summary.id.uuidString)
        }
        
        // Perform search
        guard let queryEmbedding = embeddingService.generateEmbedding(for: "performance test search query") else {
            XCTFail("Failed to generate query embedding")
            return
        }
        
        let _ = try await sqliteVecSchema.searchSimilarVectors(queryEmbedding, limit: 5)
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Should complete 20 summaries + search in reasonable time
        XCTAssertLessThan(totalTime, 30.0, "Full round-trip for 20 summaries should complete in under 30 seconds")
        
        print("⚡ Performance test completed in \(String(format: "%.2f", totalTime)) seconds")
        print("📈 Average time per summary: \(String(format: "%.3f", totalTime / Double(testSummaries.count))) seconds")
    }
}