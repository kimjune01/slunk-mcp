import XCTest
import Foundation
@testable import slunk_swift

final class SimpleEnhancedTest: XCTestCase {
    
    func testBasicEnhancedStorage() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("simple_enhanced_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        
        // Create a simple TextSummary with enhanced fields
        let summary = TextSummary(
            title: "Test Enhanced",
            content: "This is test content",
            summary: "Test summary",
            sender: "Alice",
            keywords: ["test", "enhanced"]
        )
        
        print("Created summary with:")
        print("  ID: \(summary.id)")
        print("  Sender: \(summary.sender ?? "nil")")
        print("  Keywords: \(summary.keywords)")
        print("  Timestamp: \(summary.timestamp)")
        
        // Create a mock embedding
        let embedding = Array(repeating: Float(0.5), count: 512)
        
        // Try to store it
        do {
            try await schema.storeSummaryWithEmbedding(summary, embedding: embedding)
            print("✅ Successfully stored summary with embedding")
        } catch {
            XCTFail("Failed to store summary: \(error)")
            return
        }
        
        // Try to query by date range
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        
        do {
            let results = try await schema.querySummariesByDateRange(start: todayString, end: todayString)
            print("✅ Successfully queried \(results.count) summaries")
            
            if let first = results.first {
                print("  First result:")
                print("    Title: \(first.title)")
                print("    Sender: \(first.sender ?? "nil")")
                print("    Keywords: \(first.keywords)")
            }
            
            XCTAssertEqual(results.count, 1, "Should find one summary for today")
        } catch {
            XCTFail("Failed to query summaries: \(error)")
        }
    }
}