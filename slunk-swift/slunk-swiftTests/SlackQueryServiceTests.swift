import XCTest
@testable import slunk_swift

final class SlackQueryServiceTests: XCTestCase {
    var embeddingService: MockEmbeddingService!
    var messageContextualizer: MessageContextualizer!
    var queryService: SlackQueryService!
    
    override func setUp() async throws {
        try await super.setUp()
        embeddingService = MockEmbeddingService()
        messageContextualizer = MessageContextualizer(embeddingService: embeddingService)
        queryService = SlackQueryService(messageContextualizer: messageContextualizer)
    }
    
    override func tearDown() async throws {
        embeddingService = nil
        messageContextualizer = nil
        queryService = nil
        try await super.tearDown()
    }
    
    // MARK: - Filter Tests
    
    func testChannelFiltering() async throws {
        let channelFilter = await queryService.filterByChannels(["engineering", "bugs"])
        
        XCTAssertEqual(channelFilter.type, .channel)
        XCTAssertEqual(channelFilter.values, ["engineering", "bugs"])
        XCTAssertTrue(channelFilter.sqlFragment.contains("channel IN"))
    }
    
    func testUserFiltering() async throws {
        let userFilter = await queryService.filterByUsers(["john.doe", "jane.smith"])
        
        XCTAssertEqual(userFilter.type, .user)
        XCTAssertEqual(userFilter.values, ["john.doe", "jane.smith"])
        XCTAssertTrue(userFilter.sqlFragment.contains("sender IN"))
    }
    
    func testTimeRangeFiltering() async throws {
        let startDate = Date().addingTimeInterval(-86400) // 1 day ago
        let endDate = Date()
        
        let timeFilter = await queryService.filterByTimeRange(from: startDate, to: endDate)
        
        XCTAssertEqual(timeFilter.type, .timeRange)
        XCTAssertTrue(timeFilter.sqlFragment.contains("BETWEEN"))
    }
    
    // MARK: - Conversation Chunk Tests
    
    func testCreateConversationChunks() async throws {
        let messages = createTestMessages()
        
        let chunks = await queryService.createConversationChunks(
            for: messages,
            timeWindow: 600
        )
        
        // Should create at least one chunk from test data
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertTrue(chunks.allSatisfy { !$0.messages.isEmpty })
        XCTAssertTrue(chunks.allSatisfy { !$0.topic.isEmpty })
    }
    
    // MARK: - Search Result Tests
    
    func testSlackSearchResult() {
        let message = SlackMessage(
            timestamp: Date(),
            sender: "test",
            content: "test message",
            channel: "general"
        )
        
        let result = SlackSearchResult(
            message: message,
            similarity: 0.8,
            contextualMeaning: "test meaning",
            threadContext: nil,
            resultType: .contextualMessage
        )
        
        XCTAssertEqual(result.message.content, "test message")
        XCTAssertEqual(result.similarity, 0.8)
        XCTAssertEqual(result.contextualMeaning, "test meaning")
        XCTAssertEqual(result.resultType, .contextualMessage)
    }
    
    func testSearchMetadata() {
        let metadata = SearchMetadata(
            totalResults: 10,
            contextualMatches: 5,
            chunkMatches: 3,
            searchType: .hybrid,
            contextEnhancement: true
        )
        
        XCTAssertEqual(metadata.totalResults, 10)
        XCTAssertEqual(metadata.contextualMatches, 5)
        XCTAssertEqual(metadata.chunkMatches, 3)
        XCTAssertEqual(metadata.searchType, .hybrid)
        XCTAssertTrue(metadata.contextEnhancement)
    }
    
    // MARK: - Helper Methods
    
    private func createTestMessages() -> [SlackMessage] {
        let now = Date()
        return [
            SlackMessage(
                id: "msg1",
                timestamp: now,
                sender: "john.doe",
                content: "Let's deploy the API changes",
                channel: "engineering"
            ),
            SlackMessage(
                id: "msg2",
                timestamp: now.addingTimeInterval(60),
                sender: "jane.smith",
                content: "👍",
                channel: "engineering",
                threadId: "msg1"
            ),
            SlackMessage(
                id: "msg3",
                timestamp: now.addingTimeInterval(120),
                sender: "bob.wilson",
                content: "LGTM for the deployment",
                channel: "engineering",
                threadId: "msg1"
            )
        ]
    }
}

// MockEmbeddingService is defined in MessageContextualizerTests.swift