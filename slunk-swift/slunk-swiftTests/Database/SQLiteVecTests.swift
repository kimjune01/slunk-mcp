import XCTest
import SQLiteVec
import Foundation
@testable import slunk_swift

final class SlackDatabaseTests: XCTestCase {
    
    var slackDatabase: SlackDatabaseSchema!
    var tempDatabaseURL: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary database file for testing
        let tempDir = FileManager.default.temporaryDirectory
        tempDatabaseURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).db")
        
        slackDatabase = try! SlackDatabaseSchema()
    }
    
    override func tearDown() {
        slackDatabase = nil
        
        // Clean up temporary database file
        if let tempURL = tempDatabaseURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        tempDatabaseURL = nil
        
        super.tearDown()
    }
    
    func testSlackDatabaseInitialization() async throws {
        // Should initialize Slack database
        try await slackDatabase.initializeDatabase()
        
        // Should handle re-initialization gracefully
        try await slackDatabase.initializeDatabase()
    }
    
    func testBasicSlackMessageOperations() async throws {
        // Initialize database first
        try await slackDatabase.initializeDatabase()
        
        // Should be able to insert a message
        let testMessage = SlackMessage(
            id: "test-123",
            timestamp: Date(),
            sender: "testuser",
            content: "Hello world",
            channel: "general",
            threadId: nil,
            messageType: .regular,
            metadata: nil
        )
        
        _ = try await slackDatabase.processMessage(testMessage, workspace: "test-workspace", channel: testMessage.channel)
        
        // Should be able to retrieve message count
        let count = try await slackDatabase.getMessageCount()
        XCTAssertGreaterThan(count, 0, "Should have at least one message")
    }
    
    func testVectorEmbeddingPlaceholders() async throws {
        // These are placeholder implementations, should not fail
        try await slackDatabase.insertEmbedding(messageId: "test", embedding: Array(repeating: 0.1, count: 512))
        
        let embedding = try await slackDatabase.getEmbedding(messageId: "test")
        XCTAssertNil(embedding, "Placeholder implementation should return nil")
        
        let results = try await slackDatabase.semanticSearch(embedding: Array(repeating: 0.1, count: 512))
        XCTAssertEqual(results.count, 0, "Placeholder implementation should return empty results")
    }
}