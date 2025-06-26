import XCTest
import Foundation
import NaturalLanguage
@testable import slunk_swift

final class SemanticSearchEndToEndTest: XCTestCase {
    
    // MARK: - Complete End-to-End Semantic Search Test (Simplified)
    
    func testSlackDatabaseSearchWorkflow() async throws {
        print("\n🚀 Starting Slack Database Search Test")
        print("=" * 60)
        
        // STEP 1: Create a fresh database
        print("\n📂 Step 1: Setting up fresh Slack database...")
        let slackDatabase = try SlackDatabaseSchema()
        try await slackDatabase.initializeDatabase()
        print("✅ Slack database initialized")
        
        // STEP 2: Add test data
        print("\n📝 Step 2: Adding test messages...")
        
        let testMessages = [
            SlackMessage(
                id: "msg-1",
                timestamp: Date(),
                sender: "alice",
                content: "Let's discuss the new API design for our Swift project",
                channel: "engineering",
                threadId: nil,
                messageType: .regular,
                metadata: nil
            ),
            SlackMessage(
                id: "msg-2", 
                timestamp: Date(),
                sender: "bob",
                content: "The database performance needs improvement",
                channel: "engineering",
                threadId: nil,
                messageType: .regular,
                metadata: nil
            ),
            SlackMessage(
                id: "msg-3",
                timestamp: Date(),
                sender: "charlie",
                content: "Great work on the UI updates!",
                channel: "design",
                threadId: nil,
                messageType: .regular,
                metadata: nil
            )
        ]
        
        for message in testMessages {
            _ = try await slackDatabase.processMessage(message, workspace: "test-workspace", channel: message.channel)
        }
        print("✅ Test messages added")
        
        // STEP 3: Test basic search
        print("\n🔍 Step 3: Testing search functionality...")
        
        let searchResults = try await slackDatabase.searchMessages(query: "API", limit: 5)
        XCTAssertGreaterThan(searchResults.count, 0, "Should find messages containing 'API'")
        
        let apiResult = searchResults.first { $0.message.content.contains("API") }
        XCTAssertNotNil(apiResult, "Should find the API-related message")
        print("✅ Basic search working: found \(searchResults.count) results")
        
        // STEP 4: Test vector embedding placeholders
        print("\n🧠 Step 4: Testing vector embedding placeholders...")
        
        let testEmbedding = Array(repeating: Float(0.1), count: 512)
        try await slackDatabase.insertEmbedding(messageId: "msg-1", embedding: testEmbedding)
        
        let retrievedEmbedding = try await slackDatabase.getEmbedding(messageId: "msg-1")
        XCTAssertNil(retrievedEmbedding, "Placeholder should return nil")
        
        let semanticResults = try await slackDatabase.semanticSearch(embedding: testEmbedding)
        XCTAssertEqual(semanticResults.count, 0, "Placeholder should return empty results")
        print("✅ Vector embedding placeholders working as expected")
        
        // STEP 5: Verify database stats
        print("\n📊 Step 5: Verifying database statistics...")
        
        let messageCount = try await slackDatabase.getMessageCount()
        XCTAssertEqual(messageCount, testMessages.count, "Should have correct message count")
        
        let workspaceCount = try await slackDatabase.getWorkspaceCount()
        XCTAssertGreaterThan(workspaceCount, 0, "Should have at least one workspace")
        
        print("✅ Database stats: \(messageCount) messages, \(workspaceCount) workspaces")
        
        print("\n🎉 End-to-End Test Completed Successfully!")
        print("=" * 60)
    }
    
    func testHybridSearchPlaceholder() async throws {
        // Test that hybrid search falls back to regular search
        let slackDatabase = try SlackDatabaseSchema()
        try await slackDatabase.initializeDatabase()
        
        let testMessage = SlackMessage(
            id: "hybrid-test",
            timestamp: Date(),
            sender: "testuser",
            content: "Hybrid search test message",
            channel: "test",
            threadId: nil,
            messageType: .regular,
            metadata: nil
        )
        
        _ = try await slackDatabase.processMessage(testMessage, workspace: "test", channel: testMessage.channel)
        
        let embedding = Array(repeating: Float(0.1), count: 512)
        let results = try await slackDatabase.hybridSearch(
            query: "hybrid",
            embedding: embedding,
            limit: 5
        )
        
        // Should fall back to keyword search and find the message
        XCTAssertGreaterThan(results.count, 0, "Hybrid search should fall back to keyword search")
        
        let foundMessage = results.first { $0.message.content.contains("Hybrid") }
        XCTAssertNotNil(foundMessage, "Should find the test message")
    }
}