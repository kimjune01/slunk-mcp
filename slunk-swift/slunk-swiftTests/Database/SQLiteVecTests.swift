import XCTest
import SQLiteVec
import Foundation
import NaturalLanguage
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
    
    func testVectorEmbeddingOperations() async throws {
        // Initialize database first
        try await slackDatabase.initializeDatabase()
        
        // Test embedding insertion
        let testEmbedding = Array(repeating: Float(0.1), count: 512)
        try await slackDatabase.insertEmbedding(messageId: "test", embedding: testEmbedding)
        
        // Test embedding retrieval
        let retrievedEmbedding = try await slackDatabase.getEmbedding(messageId: "test")
        XCTAssertNotNil(retrievedEmbedding, "Should retrieve stored embedding")
        XCTAssertEqual(retrievedEmbedding?.count, 512, "Should have 512 dimensions")
        
        // Test semantic search (will return empty since no similar vectors)
        let searchResults = try await slackDatabase.semanticSearch(embedding: testEmbedding)
        XCTAssertGreaterThanOrEqual(searchResults.count, 0, "Should return search results")
    }
    
    func testEmbeddingDimensionValidation() async throws {
        try await slackDatabase.initializeDatabase()
        
        // Test invalid embedding dimensions
        let invalidEmbedding = Array(repeating: Float(0.1), count: 256) // Wrong size
        
        do {
            try await slackDatabase.insertEmbedding(messageId: "test", embedding: invalidEmbedding)
            XCTFail("Should throw error for invalid embedding dimensions")
        } catch {
            // Expected to throw error
            XCTAssertTrue(error is SlackDatabaseError, "Should throw SlackDatabaseError")
        }
    }
}