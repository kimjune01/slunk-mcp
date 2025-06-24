import XCTest
import Foundation
import SQLiteVec
@testable import slunk_swift

final class MinimalRoundTripTest: XCTestCase {
    
    func testJustTextSummary() throws {
        // Test just the TextSummary creation
        let summary = TextSummary(
            title: "Test",
            content: "Test content",
            summary: "Test summary"
        )
        
        XCTAssertEqual(summary.title, "Test")
        XCTAssertEqual(summary.content, "Test content")
        XCTAssertEqual(summary.summary, "Test summary")
        
        print("✅ TextSummary creation works")
    }
    
    func testJustEmbedding() throws {
        // Test just the embedding generation
        let service = EmbeddingService()
        let embedding = service.generateEmbedding(for: "test text")
        
        XCTAssertNotNil(embedding)
        XCTAssertEqual(embedding?.count, 512)
        
        print("✅ Embedding generation works")
    }
    
    func testJustSQLiteVecInit() async throws {
        // Test just SQLiteVec initialization
        try SQLiteVec.initialize()
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("minimal_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let db = try Database(.uri(tempURL.path))
        let version = await db.version()
        XCTAssertNotNil(version)
        
        print("✅ SQLiteVec initialization works, version: \(version ?? "unknown")")
    }
    
    func testJustVectorTable() async throws {
        // Test just vector table creation
        try SQLiteVec.initialize()
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("table_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let db = try Database(.uri(tempURL.path))
        
        // Create vector table
        try await db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS test_embeddings USING vec0(
                embedding float[512],
                summary_id text
            )
        """)
        
        // Verify table exists
        let result = try await db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='test_embeddings'")
        XCTAssertFalse(result.isEmpty, "Table should exist")
        
        print("✅ Vector table creation works")
    }
    
    func testJustVectorInsert() async throws {
        // Test just vector insertion
        try SQLiteVec.initialize()
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("insert_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let db = try Database(.uri(tempURL.path))
        
        // Create vector table
        try await db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS test_embeddings USING vec0(
                embedding float[512],
                summary_id text
            )
        """)
        
        // Insert a test vector
        let testVector: [Float] = Array(repeating: 0.1, count: 512)
        try await db.execute(
            "INSERT INTO test_embeddings (embedding, summary_id) VALUES (?, ?)",
            params: [testVector, "test-id"]
        )
        
        // Query back
        let result = try await db.query(
            "SELECT summary_id FROM test_embeddings WHERE summary_id = ?",
            params: ["test-id"]
        )
        
        XCTAssertEqual(result.count, 1, "Should find one result")
        XCTAssertEqual(result[0]["summary_id"] as? String, "test-id", "Should find correct ID")
        
        print("✅ Vector insertion works")
    }
}