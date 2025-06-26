import XCTest
@testable import slunk_swift

final class MessageContextualizerBasicTests: XCTestCase {
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
    
    // MARK: - Basic Context Tests (without database)
    
    func testEnhanceWithChannelContext() async throws {
        let message = SlackMessage(
            timestamp: Date(),
            sender: "jane.smith",
            content: "LGTM",
            channel: "engineering"
        )
        
        let enhancedContent = await contextualizer.enhanceWithChannelContext(message: message)
        
        XCTAssertTrue(enhancedContent.contains("Channel:"))
        XCTAssertTrue(enhancedContent.contains("Time:"))
        XCTAssertTrue(enhancedContent.contains("Sender: jane.smith"))
        XCTAssertTrue(enhancedContent.contains("Content: LGTM"))
    }
    
    func testChannelTopicMapping() async throws {
        let engineeringMessage = SlackMessage(
            timestamp: Date(),
            sender: "dev",
            content: "test",
            channel: "engineering"
        )
        
        let enhancedContent = await contextualizer.enhanceWithChannelContext(message: engineeringMessage)
        XCTAssertTrue(enhancedContent.contains("Software development and technical discussions"))
        
        let bugsMessage = SlackMessage(
            timestamp: Date(),
            sender: "dev",
            content: "test",
            channel: "bugs"
        )
        
        let bugsEnhanced = await contextualizer.enhanceWithChannelContext(message: bugsMessage)
        XCTAssertTrue(bugsEnhanced.contains("Bug reports and issue tracking"))
    }
    
    func testShortResponseDetection() async throws {
        // Test emoji detection
        let emojiMessage = SlackMessage(timestamp: Date(), sender: "user", content: "👍", channel: "general")
        let emojiMeaning = await contextualizer.extractContextualMeaning(from: emojiMessage)
        XCTAssertNotNil(emojiMeaning)
        XCTAssertTrue(emojiMeaning!.contains("approval"))
        
        // Test abbreviation detection  
        let lgtmMessage = SlackMessage(timestamp: Date(), sender: "user", content: "lgtm", channel: "general")
        let lgtmMeaning = await contextualizer.extractContextualMeaning(from: lgtmMessage)
        XCTAssertNotNil(lgtmMeaning)
        XCTAssertTrue(lgtmMeaning!.contains("looks good to me"))
        
        // Test regular message (should return nil without thread context)
        let regularMessage = SlackMessage(timestamp: Date(), sender: "user", 
                                        content: "This is a longer message that shouldn't be considered short",
                                        channel: "general")
        let regularMeaning = await contextualizer.extractContextualMeaning(from: regularMessage)
        XCTAssertNil(regularMeaning)
    }
    
    func testContextualMeaningWithThreadContext() async throws {
        let parentMessage = SlackMessage(
            id: "parent",
            timestamp: Date(),
            sender: "alice",
            content: "Should we deploy the API changes?",
            channel: "engineering"
        )
        
        let threadContext = ThreadContext(
            threadId: "thread1",
            parentMessage: parentMessage,
            recentMessages: [parentMessage],
            totalMessageCount: 2
        )
        
        let emojiMessage = SlackMessage(
            id: "reply",
            timestamp: Date(),
            sender: "bob",
            content: "👍",
            channel: "engineering",
            threadId: "thread1"
        )
        
        let meaning = await contextualizer.extractContextualMeaning(
            from: emojiMessage,
            threadContext: threadContext
        )
        
        XCTAssertNotNil(meaning)
        XCTAssertTrue(meaning!.contains("approval"))
        XCTAssertTrue(meaning!.contains("Should we deploy the API changes?"))
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
    
    func testConversationChunkTimeWindowing() async throws {
        // Create messages with different time gaps
        let now = Date()
        let messages = [
            SlackMessage(id: "1", timestamp: now, sender: "user1", content: "First message", channel: "test"),
            SlackMessage(id: "2", timestamp: now.addingTimeInterval(60), sender: "user2", content: "Quick reply", channel: "test"),
            SlackMessage(id: "3", timestamp: now.addingTimeInterval(120), sender: "user1", content: "Another quick reply", channel: "test"),
            // Large time gap - should create new chunk
            SlackMessage(id: "4", timestamp: now.addingTimeInterval(900), sender: "user3", content: "New topic started", channel: "test"),
            SlackMessage(id: "5", timestamp: now.addingTimeInterval(960), sender: "user1", content: "Response to new topic", channel: "test")
        ]
        
        let chunks = await contextualizer.createConversationChunks(
            from: messages,
            timeWindow: 300 // 5 minutes
        )
        
        // Should create at least 2 chunks due to time gap
        XCTAssertGreaterThanOrEqual(chunks.count, 2)
    }
    
    func testGenerateContextualEmbedding() async throws {
        let message = SlackMessage(
            id: "test",
            timestamp: Date(),
            sender: "user",
            content: "👍",
            channel: "engineering",
            threadId: "thread1"
        )
        
        let embedding = try await contextualizer.generateContextualEmbedding(for: message)
        
        XCTAssertEqual(embedding.count, 512)
        XCTAssertTrue(embedding.allSatisfy { $0 >= 0 && $0 <= 1 })
    }
    
    func testGenerateChunkEmbedding() async throws {
        let messages = createTestMessages()
        let chunks = await contextualizer.createConversationChunks(from: messages)
        
        guard let firstChunk = chunks.first else {
            XCTFail("No chunks created")
            return
        }
        
        let embedding = try await contextualizer.generateChunkEmbedding(for: firstChunk)
        
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
                content: "We need to deploy the API changes",
                channel: "engineering"
            ),
            SlackMessage(
                id: "2", 
                timestamp: now.addingTimeInterval(60),
                sender: "bob",
                content: "The API tests are passing",
                channel: "engineering"
            ),
            SlackMessage(
                id: "3",
                timestamp: now.addingTimeInterval(120),
                sender: "carol",
                content: "Database migration is ready",
                channel: "engineering"
            ),
            SlackMessage(
                id: "4",
                timestamp: now.addingTimeInterval(180),
                sender: "alice",
                content: "Let's deploy at 2 PM",
                channel: "engineering"
            ),
            SlackMessage(
                id: "5",
                timestamp: now.addingTimeInterval(240),
                sender: "bob",
                content: "👍",
                channel: "engineering"
            )
        ]
    }
}

// MockEmbeddingService is defined in MessageContextualizerTests.swift