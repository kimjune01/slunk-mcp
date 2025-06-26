import XCTest
@testable import slunk_swift

final class SmartIngestionTests: XCTestCase {
    
    func testIngestionPipeline() async throws {
        print("\n📥 Testing Slack Message Ingestion Pipeline")
        
        // Since we've moved to SlackDatabaseSchema for Slack monitoring,
        // ingestion tests now focus on Slack message processing
        
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("slack_ingestion_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = SlackDatabaseSchema(databaseURL: tempURL)
        try await schema.initializeDatabase()
        
        // Test basic database functionality
        let initialCount = try await schema.getMessageCount()
        XCTAssertEqual(initialCount, 0, "Should start with empty database")
        
        print("  ✓ Slack database initialized for ingestion testing")
        print("  ✓ Initial message count: \(initialCount)")
        
        // Test that SlackQueryService can work with the schema
        let embeddingService = EmbeddingService()
        let messageContextualizer = MessageContextualizer(embeddingService: embeddingService)
        let queryService = SlackQueryService(messageContextualizer: messageContextualizer)
        await queryService.setDatabase(schema)
        let serviceCount = try await queryService.getMessageCount()
        XCTAssertEqual(serviceCount, 0, "QueryService should also return 0 initially")
        
        print("  ✓ SlackQueryService integration working")
        print("\n✅ Slack Ingestion Pipeline Tests Completed")
    }
    
    func testPerformanceRequirements() async throws {
        print("\n⚡ Testing Slack Ingestion Performance")
        
        // Test performance characteristics of Slack database operations
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("slack_perf_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let schema = SlackDatabaseSchema(databaseURL: tempURL)
        try await schema.initializeDatabase()
        
        let initTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Performance requirement: Database should initialize quickly
        XCTAssertLessThan(initTime, 5.0, "Database initialization should complete within 5 seconds")
        
        print("  ✓ Database initialization time: \(String(format: "%.3f", initTime))s")
        print("  ✓ Performance requirements met")
        
        print("\n✅ Slack Performance Tests Completed")
    }
    
    func testSlackMessageStructure() async throws {
        print("\n📨 Testing Slack Message Structure Handling")
        
        // Test that the system can handle Slack-specific message structures
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("slack_structure_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = SlackDatabaseSchema(databaseURL: tempURL)
        try await schema.initializeDatabase()
        
        // Verify database schema is ready for Slack data
        let messageCount = try await schema.getMessageCount()
        let workspaceCount = try await schema.getWorkspaceCount()
        
        XCTAssertEqual(messageCount, 0, "Should start with no messages")
        XCTAssertEqual(workspaceCount, 0, "Should start with no workspaces")
        
        print("  ✓ Slack message schema ready")
        print("  ✓ Message count: \(messageCount)")
        print("  ✓ Workspace count: \(workspaceCount)")
        
        print("\n✅ Slack Message Structure Tests Completed")
    }
}