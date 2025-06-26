import XCTest
@testable import slunk_swift

final class MessageContextualizerTests: XCTestCase {
    var embeddingService: EmbeddingService!
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
    
    // MARK: - Thread Context Tests
    
    func testEnhanceWithThreadContext() async throws {
        let message = SlackMessage(
            id: "msg1",
            timestamp: Date(),
            sender: "john.doe",
            content: "👍",
            threadId: "thread1"
        )
        
        let enhancedContent = await contextualizer.enhanceWithThreadContext(message: message)
        
        XCTAssertTrue(enhancedContent.contains("Thread context:"))
        XCTAssertTrue(enhancedContent.contains("Current: 👍"))
        XCTAssertTrue(enhancedContent.contains("Channel:"))
    }
    
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
    
    func testGetChannelTopic() async throws {
        // Test common channel patterns
        let engineeringMessage = SlackMessage(
            timestamp: Date(),
            sender: "dev",
            content: "test",
            channel: "engineering"
        )
        
        let enhancedContent = await contextualizer.enhanceWithChannelContext(message: engineeringMessage)
        XCTAssertTrue(enhancedContent.contains("Software development and technical discussions"))
        
        // Test default channel topic
        let defaultMessage = SlackMessage(
            timestamp: Date(),
            sender: "dev",
            content: "test",
            channel: "unknown-channel"
        )
        
        let defaultContent = await contextualizer.enhanceWithChannelContext(message: defaultMessage)
        XCTAssertTrue(defaultContent.contains("Team discussions in #unknown-channel"))
    }
    
    // MARK: - Contextual Meaning Tests
    
    func testExtractContextualMeaningForEmoji() async throws {
        let parentMessage = SlackMessage(
            id: "parent",
            timestamp: Date(),
            sender: "alice",
            content: "Should we deploy the API changes?"
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
    
    func testExtractContextualMeaningForLGTM() async throws {
        let parentMessage = SlackMessage(
            id: "parent",
            timestamp: Date(),
            sender: "dev1",
            content: "Here's the code review for the new feature"
        )
        
        let threadContext = ThreadContext(
            threadId: "thread1",
            parentMessage: parentMessage,
            recentMessages: [parentMessage],
            totalMessageCount: 2
        )
        
        let lgtmMessage = SlackMessage(
            id: "reply",
            timestamp: Date(),
            sender: "dev2",
            content: "lgtm",
            threadId: "thread1"
        )
        
        let meaning = await contextualizer.extractContextualMeaning(
            from: lgtmMessage,
            threadContext: threadContext
        )
        
        XCTAssertNotNil(meaning)
        XCTAssertTrue(meaning!.contains("looks good to me"))
    }
    
    func testExtractContextualMeaningForRegularMessage() async throws {
        let parentMessage = SlackMessage(
            id: "parent",
            timestamp: Date(),
            sender: "pm",
            content: "What's the status of the API integration?"
        )
        
        let threadContext = ThreadContext(
            threadId: "thread1",
            parentMessage: parentMessage,
            recentMessages: [parentMessage],
            totalMessageCount: 2
        )
        
        let regularMessage = SlackMessage(
            id: "reply",
            timestamp: Date(),
            sender: "dev",
            content: "The integration is 80% complete, expecting to finish by Friday",
            threadId: "thread1"
        )
        
        let meaning = await contextualizer.extractContextualMeaning(
            from: regularMessage,
            threadContext: threadContext
        )
        
        XCTAssertNotNil(meaning)
        XCTAssertTrue(meaning!.contains("Response in thread about"))
        XCTAssertTrue(meaning!.contains("What's the status of the API integration?"))
    }
    
    func testIsShortResponse() async throws {
        // Test emoji detection
        let emojiMessage = SlackMessage(timestamp: Date(), sender: "user", content: "👍")
        let emojiMeaning = await contextualizer.extractContextualMeaning(from: emojiMessage)
        XCTAssertNotNil(emojiMeaning)
        
        // Test abbreviation detection  
        let lgtmMessage = SlackMessage(timestamp: Date(), sender: "user", content: "lgtm")
        let lgtmMeaning = await contextualizer.extractContextualMeaning(from: lgtmMessage)
        XCTAssertNotNil(lgtmMeaning)
        
        // Test regular message (should return nil without thread context)
        let regularMessage = SlackMessage(timestamp: Date(), sender: "user", 
                                        content: "This is a longer message that shouldn't be considered short")
        let regularMeaning = await contextualizer.extractContextualMeaning(from: regularMessage)
        XCTAssertNil(regularMeaning)
    }
    
    // MARK: - Conversation Chunking Tests
    
    func testCreateConversationChunks() async throws {
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
            SlackMessage(id: "1", timestamp: now, sender: "user1", content: "First message"),
            SlackMessage(id: "2", timestamp: now.addingTimeInterval(60), sender: "user2", content: "Quick reply"),
            SlackMessage(id: "3", timestamp: now.addingTimeInterval(120), sender: "user1", content: "Another quick reply"),
            // Large time gap - should create new chunk
            SlackMessage(id: "4", timestamp: now.addingTimeInterval(900), sender: "user3", content: "New topic started"),
            SlackMessage(id: "5", timestamp: now.addingTimeInterval(960), sender: "user1", content: "Response to new topic")
        ]
        
        let chunks = await contextualizer.createConversationChunks(
            from: messages,
            timeWindow: 300 // 5 minutes
        )
        
        // Should create at least 2 chunks due to time gap
        XCTAssertGreaterThanOrEqual(chunks.count, 2)
    }
    
    func testConversationChunkSizeLimit() async throws {
        // Create many messages to test size-based chunking
        var messages: [SlackMessage] = []
        let now = Date()
        
        for i in 0..<25 {
            messages.append(SlackMessage(
                id: "msg\(i)",
                timestamp: now.addingTimeInterval(TimeInterval(i * 30)), // 30 seconds apart
                sender: "user\(i % 3)", // Rotate between 3 users
                content: "Message number \(i)"
            ))
        }
        
        let chunks = await contextualizer.createConversationChunks(
            from: messages,
            timeWindow: 3600 // 1 hour (should not trigger time-based chunking)
        )
        
        // Should create multiple chunks due to size limit (20 messages per chunk)
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { $0.messages.count <= 20 })
    }
    
    func testGenerateChunkTopic() async throws {
        let messages = [
            SlackMessage(timestamp: Date(), sender: "dev1", content: "API deployment is ready"),
            SlackMessage(timestamp: Date(), sender: "dev2", content: "Deployment looks good"),
            SlackMessage(timestamp: Date(), sender: "pm", content: "Deploy when ready")
        ]
        
        let chunks = await contextualizer.createConversationChunks(from: messages)
        
        XCTAssertFalse(chunks.isEmpty)
        let firstChunk = chunks[0]
        XCTAssertFalse(firstChunk.topic.isEmpty)
        // Topic should contain relevant keywords
        XCTAssertTrue(firstChunk.topic.lowercased().contains("deploy") || 
                     firstChunk.topic.lowercased().contains("api"))
    }
    
    func testGenerateChunkSummary() async throws {
        let messages = createTestMessages()
        
        let chunks = await contextualizer.createConversationChunks(from: messages)
        
        XCTAssertFalse(chunks.isEmpty)
        let firstChunk = chunks[0]
        XCTAssertFalse(firstChunk.summary.isEmpty)
        XCTAssertTrue(firstChunk.summary.contains("messages"))
        XCTAssertTrue(firstChunk.summary.contains("participants"))
    }
    
    // MARK: - Enhanced Embedding Pipeline Tests
    
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

// MARK: - Mock Embedding Service

class MockEmbeddingService: EmbeddingService {
    override func generateEmbedding(for text: String) async throws -> [Float] {
        // Generate deterministic embeddings based on text content
        let hash = abs(text.hashValue)
        return Array(0..<512).map { i in 
            Float((hash + i) % 100) / 100.0 
        }
    }
}