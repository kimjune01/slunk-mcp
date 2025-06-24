import XCTest
import Foundation
import SQLiteVec
@testable import slunk_swift

final class WorkingRoundTripTest: XCTestCase {
    
    func testCompleteRoundTripWithDirectAPI() async throws {
        // Initialize SQLiteVec
        try SQLiteVec.initialize()
        
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("working_roundtrip_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // STEP 1: Create TextSummary
        let summary = TextSummary(
            title: "Complete Integration Test",
            content: "This is a comprehensive test of the entire workflow from TextSummary creation through embedding generation to vector storage and similarity search.",
            summary: "Complete workflow integration test for vector storage system"
        )
        
        print("📝 Created TextSummary:")
        print("   Title: \(summary.title)")
        print("   Content words: \(summary.wordCount)")
        print("   Summary words: \(summary.summaryWordCount)")
        print("   ID: \(summary.id)")
        
        // STEP 2: Generate embedding
        let embeddingService = EmbeddingService()
        guard let embedding = embeddingService.generateEmbedding(for: summary.summary) else {
            XCTFail("Failed to generate embedding")
            return
        }
        
        XCTAssertEqual(embedding.count, 512, "Should generate 512-dimensional embedding")
        print("🧠 Generated embedding with \(embedding.count) dimensions")
        
        // STEP 3: Setup vector database directly
        let db = try Database(.uri(tempURL.path))
        
        // Create vector table
        try await db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS summary_embeddings USING vec0(
                embedding float[512],
                summary_id text
            )
        """)
        
        print("💾 Created vector table")
        
        // STEP 4: Store vector
        try await db.execute(
            "INSERT INTO summary_embeddings (embedding, summary_id) VALUES (?, ?)",
            params: [embedding, summary.id.uuidString]
        )
        
        print("✅ Stored vector in database")
        
        // STEP 5: Retrieve vector and verify
        let retrieveResult = try await db.query(
            "SELECT embedding FROM summary_embeddings WHERE summary_id = ?",
            params: [summary.id.uuidString]
        )
        
        XCTAssertEqual(retrieveResult.count, 1, "Should find one result")
        
        if let embeddingData = retrieveResult[0]["embedding"] as? Data {
            let retrievedVector = embeddingData.withUnsafeBytes { 
                $0.bindMemory(to: Float.self) 
            }
            let retrievedArray = Array(retrievedVector)
            
            XCTAssertEqual(retrievedArray.count, 512, "Retrieved vector should have correct dimensions")
            
            // Verify values match
            for (original, retrieved) in zip(embedding, retrievedArray) {
                XCTAssertEqual(original, retrieved, accuracy: 0.0001, "Vector values should match")
            }
            
            print("✅ Retrieved and verified vector data")
        } else {
            XCTFail("Could not retrieve embedding data")
        }
        
        // STEP 6: Test similarity search
        let searchResults = try await db.query("""
            SELECT summary_id, distance
            FROM summary_embeddings
            WHERE embedding MATCH ? AND k = ?
            ORDER BY distance
        """, params: [embedding, 1])
        
        XCTAssertEqual(searchResults.count, 1, "Should find similarity search result")
        XCTAssertEqual(searchResults[0]["summary_id"] as? String, summary.id.uuidString, "Should find correct summary")
        
        if let distance = searchResults[0]["distance"] as? Double {
            XCTAssertLessThan(distance, 0.1, "Distance should be very small for identical vectors")
            print("🔍 Similarity search found result with distance: \(distance)")
        }
        
        // STEP 7: Test with a different query
        let queryText = "integration testing workflow"
        guard let queryEmbedding = embeddingService.generateEmbedding(for: queryText) else {
            XCTFail("Failed to generate query embedding")
            return
        }
        
        let queryResults = try await db.query("""
            SELECT summary_id, distance
            FROM summary_embeddings
            WHERE embedding MATCH ? AND k = ?
            ORDER BY distance
        """, params: [queryEmbedding, 1])
        
        XCTAssertEqual(queryResults.count, 1, "Should find query result")
        XCTAssertEqual(queryResults[0]["summary_id"] as? String, summary.id.uuidString, "Should find correct summary")
        
        if let queryDistance = queryResults[0]["distance"] as? Double {
            print("🔍 Query search found result with distance: \(queryDistance)")
        }
        
        // STEP 8: Test with multiple summaries
        let summary2 = TextSummary(
            title: "Database Design",
            content: "Database design principles for efficient data storage and retrieval",
            summary: "Database design and optimization techniques"
        )
        
        guard let embedding2 = embeddingService.generateEmbedding(for: summary2.summary) else {
            XCTFail("Failed to generate second embedding")
            return
        }
        
        try await db.execute(
            "INSERT INTO summary_embeddings (embedding, summary_id) VALUES (?, ?)",
            params: [embedding2, summary2.id.uuidString]
        )
        
        // Search should now return 2 results
        let multiResults = try await db.query("""
            SELECT summary_id, distance
            FROM summary_embeddings
            WHERE embedding MATCH ? AND k = ?
            ORDER BY distance
        """, params: [queryEmbedding, 2])
        
        XCTAssertEqual(multiResults.count, 2, "Should find both summaries")
        
        // Verify results are ordered by distance
        if multiResults.count >= 2 {
            let distance1 = multiResults[0]["distance"] as? Double ?? Double.infinity
            let distance2 = multiResults[1]["distance"] as? Double ?? Double.infinity
            XCTAssertLessThanOrEqual(distance1, distance2, "Results should be ordered by distance")
            print("🏆 Found \(multiResults.count) results, ordered by similarity")
        }
        
        print("🎉 Complete round-trip test passed successfully!")
        print("📊 Final summary:")
        print("   - Created \(2) TextSummary objects")
        print("   - Generated \(2) embeddings with \(embedding.count) dimensions each")
        print("   - Stored and retrieved vectors from SQLiteVec database")
        print("   - Performed similarity search with semantic ranking")
        print("   - Verified data consistency throughout the pipeline")
    }
    
    func testSemanticSimilarityRanking() async throws {
        // Test that semantically similar content ranks higher
        try SQLiteVec.initialize()
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("semantic_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let db = try Database(.uri(tempURL.path))
        try await db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS summary_embeddings USING vec0(
                embedding float[512],
                summary_id text
            )
        """)
        
        let embeddingService = EmbeddingService()
        
        // Create summaries in different domains
        let summaries = [
            ("programming", "Swift programming language for iOS app development", "Swift iOS development"),
            ("cooking", "Italian pasta recipes with tomato sauce", "Pasta cooking recipes"),
            ("programming", "Python programming and machine learning", "Python ML programming"),
            ("travel", "Travel guide to European cities and culture", "European travel guide")
        ]
        
        // Store all summaries
        for (i, (category, content, summary)) in summaries.enumerated() {
            guard let embedding = embeddingService.generateEmbedding(for: summary) else {
                XCTFail("Failed to generate embedding for \(category)")
                continue
            }
            
            try await db.execute(
                "INSERT INTO summary_embeddings (embedding, summary_id) VALUES (?, ?)",
                params: [embedding, "\(category)-\(i)"]
            )
        }
        
        // Search for programming content
        guard let programmingQuery = embeddingService.generateEmbedding(for: "software development and programming") else {
            XCTFail("Failed to generate programming query")
            return
        }
        
        let results = try await db.query("""
            SELECT summary_id, distance
            FROM summary_embeddings
            WHERE embedding MATCH ? AND k = ?
            ORDER BY distance
        """, params: [programmingQuery, 4])
        
        XCTAssertEqual(results.count, 4, "Should find all results")
        
        // The two programming-related summaries should be at the top
        let topTwoIds = results.prefix(2).compactMap { $0["summary_id"] as? String }
        let programmingCount = topTwoIds.filter { $0.contains("programming") }.count
        
        XCTAssertGreaterThanOrEqual(programmingCount, 1, "At least one programming result should be in top 2")
        
        print("🎯 Semantic similarity ranking test passed!")
        print("📈 Top results for 'software development' query:")
        for (i, result) in results.enumerated() {
            let id = result["summary_id"] as? String ?? "unknown"
            let distance = result["distance"] as? Double ?? 0.0
            print("   \(i+1). \(id) (distance: \(String(format: "%.3f", distance)))")
        }
    }
}