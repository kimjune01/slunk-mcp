import XCTest
import Foundation
@testable import slunk_swift

final class SimpleEnhancedTest: XCTestCase {
    
    func testBasicSlackStorage() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("simple_slack_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = SlackDatabaseSchema(databaseURL: tempURL)
        try await schema.initializeDatabase()
        
        // Create a simple Slack message
        let message = SlackMessage(
            timestamp: Date(),
            sender: "Alice",
            content: "This is a test message",
            channel: "general",
            threadId: nil,
            messageType: .regular,
            metadata: SlackMessage.MessageMetadata(
                editedAt: nil,
                reactions: [:],
                mentions: [],
                attachmentNames: [],
                contentHash: nil,
                version: 1
            )
        )
        
        print("Created message:")
        print("  ID: \(message.id)")
        print("  Sender: \(message.sender)")
        print("  Channel: \(message.channel)")
        print("  Timestamp: \(message.timestamp)")
        
        // Process the message
        do {
            let result = try await schema.processMessage(
                message,
                workspace: "test-workspace",
                channel: "general"
            )
            
            switch result {
            case .new(let messageId):
                print("✅ Stored new message with ID: \(messageId)")
            case .duplicate:
                print("⚠️ Message was a duplicate")
            case .updated(let messageId):
                print("📝 Updated existing message: \(messageId)")
            case .reactionsUpdated(let messageId):
                print("🙂 Updated reactions for message: \(messageId)")
            }
        } catch {
            XCTFail("Failed to process message: \(error)")
            return
        }
        
        // Verify storage
        do {
            let messageCount = try await schema.getMessageCount()
            print("✅ Total messages in database: \(messageCount)")
            XCTAssertEqual(messageCount, 1, "Should have one message")
            
            let workspaceCount = try await schema.getWorkspaceCount()
            print("✅ Total workspaces: \(workspaceCount)")
            XCTAssertEqual(workspaceCount, 1, "Should have one workspace")
        } catch {
            XCTFail("Failed to query database: \(error)")
        }
    }
}