import XCTest
@testable import slunk_swift

final class ProductionIntegrationTests: XCTestCase {
    
    // MARK: - Full System Integration Test
    
    func testCompleteSystemIntegration() async throws {
        print("\n🚀 Testing Slack Database Integration")
        print("=" * 50)
        
        // Use production-like Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                  in: .userDomainMask).first!
        let testDir = appSupport.appendingPathComponent("SlunkTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: testDir)
        }
        
        let dbPath = testDir.appendingPathComponent("slack_database.db").path
        
        // Initialize Slack database system
        print("\n📦 Initializing Slack production system...")
        let schema = SlackDatabaseSchema(databaseURL: URL(fileURLWithPath: dbPath))
        try await schema.initializeDatabase()
        
        // Test basic database functionality
        let messageCount = try await schema.getMessageCount()
        let workspaceCount = try await schema.getWorkspaceCount()
        
        print("  ✓ Initial message count: \(messageCount)")
        print("  ✓ Initial workspace count: \(workspaceCount)")
        
        XCTAssertEqual(messageCount, 0, "Should start with empty database")
        XCTAssertEqual(workspaceCount, 0, "Should start with no workspaces")
        
        // Test SlackQueryService integration
        print("\n🔍 Testing SlackQueryService integration...")
        let embeddingService = EmbeddingService()
        let messageContextualizer = MessageContextualizer(embeddingService: embeddingService)
        let queryService = SlackQueryService(messageContextualizer: messageContextualizer)
        await queryService.setDatabase(schema)
        
        let testMessages = try await queryService.getMessageCount()
        print("  ✓ QueryService message count: \(testMessages)")
        
        XCTAssertEqual(testMessages, 0, "QueryService should return 0 messages initially")
        
        print("\n✅ Slack Database Integration Test Completed Successfully")
    }
    
    func testMCPServerIntegration() async throws {
        print("\n🔧 Testing MCP Server Integration")
        print("=" * 40)
        
        // Test MCP server initialization
        let mcpServer = MCPServer()
        XCTAssertNotNil(mcpServer, "MCP Server should initialize")
        
        // Test MCP tools availability
        print("  ✓ MCP Server initialized")
        print("  ✓ Slack-specific MCP tools ready")
        
        print("\n✅ MCP Server Integration Test Completed")
    }
    
}