import XCTest
@testable import slunk_swift

final class EnhancedVectorStoreTests: XCTestCase {
    
    func testPersistentDatabase() async throws {
        print("\n💾 Testing Slack Database Persistence")
        
        // Test persistent database operations with SlackDatabaseSchema
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("slack_persistence_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // Test database creation and initialization
        let schema = SlackDatabaseSchema(databaseURL: tempURL)
        try await schema.initializeDatabase()
        
        // Verify database file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path), "Database file should exist")
        
        // Test basic operations
        let messageCount = try await schema.getMessageCount()
        let workspaceCount = try await schema.getWorkspaceCount()
        
        XCTAssertEqual(messageCount, 0, "Should start with no messages")
        XCTAssertEqual(workspaceCount, 0, "Should start with no workspaces")
        
        print("  ✓ Database file created at: \(tempURL.path)")
        print("  ✓ Initial message count: \(messageCount)")
        print("  ✓ Initial workspace count: \(workspaceCount)")
        
        print("\n✅ Slack Database Persistence Tests Completed")
    }
    
    
    func testSlackDataStructures() async throws {
        print("\n📋 Testing Slack Data Structure Support")
        
        // Test that the system supports Slack-specific data structures
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("slack_structures_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = SlackDatabaseSchema(databaseURL: tempURL)
        try await schema.initializeDatabase()
        
        // Verify Slack-specific functionality
        let databaseSize = try await schema.getDatabaseSize()
        XCTAssertGreaterThan(databaseSize, 0, "Database should have non-zero size after initialization")
        
        print("  ✓ Slack database schema initialized")
        print("  ✓ Database size: \(databaseSize) bytes")
        
        print("\n✅ Slack Data Structure Tests Completed")
    }
    
}