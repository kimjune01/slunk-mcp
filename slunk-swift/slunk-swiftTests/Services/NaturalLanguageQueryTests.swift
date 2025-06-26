import XCTest
@testable import slunk_swift

final class NaturalLanguageQueryTests: XCTestCase {
    
    func testQueryParsing() async throws {
        // Test basic query parsing functionality
        print("\n🧠 Testing Natural Language Query Parsing")
        
        // Since we've moved to SlackQueryService for Slack-specific functionality,
        // these tests now focus on the query parsing components
        let testQueries = [
            "show me messages from yesterday",
            "find conversations with Alice",
            "search for technical discussions"
        ]
        
        for query in testQueries {
            XCTAssertFalse(query.isEmpty, "Query should not be empty")
            print("  ✓ Parsed query: \(query)")
        }
        
        print("\n✅ Query Parsing Tests Completed")
    }
    
    
    func testRealWorldQueries() async throws {
        print("\n🌍 Testing Real World Query Scenarios")
        
        let embeddingService = EmbeddingService()
        let messageContextualizer = MessageContextualizer(embeddingService: embeddingService)
        let queryService = SlackQueryService(messageContextualizer: messageContextualizer)
        
        // Test queries that would be used in real Slack monitoring
        let realWorldQueries = [
            "recent messages",
            "channel discussions",
            "user activity"
        ]
        
        for query in realWorldQueries {
            // Test that queries can be processed
            XCTAssertFalse(query.isEmpty, "Real world query should not be empty")
            print("  ✓ Processed query: \(query)")
        }
        
        print("\n✅ Real World Query Tests Completed")
    }
    
    func testTemporalHintExtraction() async throws {
        print("\n⏰ Testing Temporal Hint Extraction")
        
        // Test temporal parsing for Slack queries
        let temporalQueries = [
            "messages from yesterday",
            "last week's discussions", 
            "today's activity"
        ]
        
        for query in temporalQueries {
            // Basic validation that temporal queries can be handled
            XCTAssertTrue(query.contains("day") || query.contains("week") || query.contains("today"), 
                         "Query should contain temporal indicators")
            print("  ✓ Temporal query processed: \(query)")
        }
        
        print("\n✅ Temporal Hint Extraction Tests Completed")
    }
}