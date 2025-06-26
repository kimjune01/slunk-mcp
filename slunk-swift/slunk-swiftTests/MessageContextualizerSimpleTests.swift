import XCTest
@testable import slunk_swift

final class MessageContextualizerSimpleTests: XCTestCase {
    var embeddingService: MockEmbeddingService!
    var contextualizer: MessageContextualizer!
    
    override func setUp() async throws {
        try await super.setUp()
        embeddingService = MockEmbeddingService()
        contextualizer = MessageContextualizer(embeddingService: embeddingService)
    }
    
    override func tearDown() async throws {
        embeddingService = nil
        contextualizer = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Context Tests
    
    func testEnhanceWithChannelContext() async throws {
        let message = SlackMessage(
            timestamp: Date(),
            sender: "jane.smith",
            content: "LGTM"
        )
        
        let enhancedContent = await contextualizer.enhanceWithChannelContext(message: message)
        
        XCTAssertTrue(enhancedContent.contains("Channel:"))
        XCTAssertTrue(enhancedContent.contains("Time:"))
        XCTAssertTrue(enhancedContent.contains("Sender: jane.smith"))
        XCTAssertTrue(enhancedContent.contains("Content: LGTM"))
    }
    
    func testShortResponseDetection() async throws {
        // Test emoji detection
        let emojiMessage = SlackMessage(timestamp: Date(), sender: "user", content: "👍")
        let emojiMeaning = await contextualizer.extractContextualMeaning(from: emojiMessage)
        XCTAssertNotNil(emojiMeaning)
        XCTAssertTrue(emojiMeaning!.contains("approval"))
        
        // Test abbreviation detection  
        let lgtmMessage = SlackMessage(timestamp: Date(), sender: "user", content: "lgtm")
        let lgtmMeaning = await contextualizer.extractContextualMeaning(from: lgtmMessage)
        XCTAssertNotNil(lgtmMeaning)
        XCTAssertTrue(lgtmMeaning!.contains("looks good to me"))
        
        // Test regular message (should return nil without thread context)
        let regularMessage = SlackMessage(timestamp: Date(), sender: "user", 
                                        content: "This is a longer message that shouldn't be considered short")
        let regularMeaning = await contextualizer.extractContextualMeaning(from: regularMessage)
        XCTAssertNil(regularMeaning)
    }
    
    func testConversationChunking() async throws {
        let messages = createTestMessages()
        
        let chunks = await contextualizer.createConversationChunks(
            from: messages,
            timeWindow: 300 // 5 minutes
        )
        
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertTrue(chunks.allSatisfy { !$0.messages.isEmpty })
        XCTAssertTrue(chunks.allSatisfy { !$0.topic.isEmpty })
        XCTAssertTrue(chunks.allSatisfy { !$0.summary.isEmpty })
    }
    
    func testGenerateContextualEmbedding() async throws {
        let message = SlackMessage(
            id: "test",
            timestamp: Date(),
            sender: "user",
            content: "👍",
            threadId: "thread1"
        )
        
        let embedding = try await contextualizer.generateContextualEmbedding(for: message)
        
        XCTAssertEqual(embedding.count, 512)
        XCTAssertTrue(embedding.allSatisfy { $0 >= 0 && $0 <= 1 })
    }
    
    // MARK: - Helper Methods
    
    private func createTestMessages() -> [SlackMessage] {
        let now = Date()
        return [
            SlackMessage(
                id: "1",
                timestamp: now,
                sender: "alice",
                content: "We need to deploy the API changes"
            ),
            SlackMessage(
                id: "2", 
                timestamp: now.addingTimeInterval(60),
                sender: "bob",
                content: "The API tests are passing"
            ),
            SlackMessage(
                id: "3",
                timestamp: now.addingTimeInterval(120),
                sender: "carol",
                content: "Database migration is ready"
            ),
            SlackMessage(
                id: "4",
                timestamp: now.addingTimeInterval(180),
                sender: "alice",
                content: "Let's deploy at 2 PM"
            ),
            SlackMessage(
                id: "5",
                timestamp: now.addingTimeInterval(240),
                sender: "bob",
                content: "👍"
            )
        ]
    }
}

// MockEmbeddingService is defined in MessageContextualizerTests.swift