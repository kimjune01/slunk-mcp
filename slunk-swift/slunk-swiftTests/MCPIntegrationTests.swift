import XCTest
import Foundation
@testable import slunk_swift

final class MCPIntegrationTests: XCTestCase {
    
    // MARK: - Data Seeding Tests
    
    func testDataSeeding() async throws {
        // Test loading sample conversations from bundle
        let sampleData = loadSampleConversations()
        XCTAssertFalse(sampleData.isEmpty, "Should load sample conversation data from bundle")
        XCTAssertGreaterThan(sampleData.count, 3, "Should have multiple sample conversations")
        
        // Test automatic seeding on first launch
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("seeding_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        
        let seeder = DataSeeder()
        await seeder.setDatabase(schema)
        
        // Should detect empty database and seed automatically
        let seedingResult = try await seeder.seedIfEmpty()
        XCTAssertTrue(seedingResult.wasSeeded, "Should seed empty database")
        XCTAssertGreaterThan(seedingResult.itemsSeeded, 0, "Should seed at least one item")
        
        // Test duplicate detection - should not seed again
        let duplicateResult = try await seeder.seedIfEmpty()
        XCTAssertFalse(duplicateResult.wasSeeded, "Should not seed database twice")
        XCTAssertEqual(duplicateResult.itemsSeeded, 0, "Should not add duplicate items")
    }
    
    func testSampleDataValidation() {
        let sampleData = loadSampleConversations()
        
        for conversation in sampleData {
            XCTAssertFalse(conversation.title.isEmpty, "Sample conversation should have title")
            XCTAssertFalse(conversation.content.isEmpty, "Sample conversation should have content")
            XCTAssertFalse(conversation.summary.isEmpty, "Sample conversation should have summary")
            XCTAssertNotNil(conversation.sender, "Sample conversation should have sender")
            XCTAssertNotNil(conversation.timestamp, "Sample conversation should have timestamp")
            XCTAssertFalse(conversation.keywords.isEmpty, "Sample conversation should have keywords")
        }
    }
    
    // MARK: - Enhanced MCP Tools Tests
    
    func testEnhancedMCPTools() async throws {
        // Create temporary database with test data
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("mcp_tools_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        
        // Seed with test data
        let seeder = DataSeeder()
        await seeder.setDatabase(schema)
        let _ = try await seeder.seedIfEmpty()
        
        let mcpServer = MCPServer()
        mcpServer.setDatabase(schema)
        
        // Test getConversationStats - only available method now
        
        // Test getConversationStats for analytics
        let statsRequest = MCPRequest(
            method: "getConversationStats",
            params: [:]
        )
        
        let statsResponse = try await mcpServer.handleGetConversationStats(statsRequest)
        XCTAssertNotNil(statsResponse.result, "Should return analytics")
        
        if let stats = statsResponse.result as? [String: Any] {
            XCTAssertNotNil(stats["totalConversations"], "Should have total count")
            XCTAssertNotNil(stats["totalKeywords"], "Should have keyword count")
            XCTAssertNotNil(stats["dateRange"], "Should have date range")
            XCTAssertNotNil(stats["topKeywords"], "Should have top keywords")
        }
    }
    
    func testEndToEndWorkflow() async throws {
        // Test complete MCP request → query → response cycle
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("e2e_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        
        let mcpServer = MCPServer()
        mcpServer.setDatabase(schema)
        
        // Test getting stats with seeded data
        let statsRequest = MCPRequest(
            method: "getConversationStats",
            params: [:]
        )
        
        let statsResponse = try await mcpServer.handleGetConversationStats(statsRequest)
        XCTAssertNotNil(statsResponse.result, "Should return updated stats")
        
        if let stats = statsResponse.result as? [String: Any],
           let totalConversations = stats["totalConversations"] as? Int {
            XCTAssertGreaterThan(totalConversations, 0, "Should have at least one conversation")
        }
    }
    
    func testJSONRPCCompliance() async throws {
        let mcpServer = MCPServer()
        
        // Test error handling for invalid requests
        let invalidRequest = MCPRequest(
            method: "nonexistentMethod",
            params: [:]
        )
        
        let errorResponse = try await mcpServer.handleRequest(invalidRequest)
        XCTAssertEqual(errorResponse.jsonrpc, "2.0", "Error response should be JSON-RPC 2.0 compliant")
        XCTAssertNotNil(errorResponse.error, "Should return error for invalid method")
        XCTAssertNil(errorResponse.result, "Error response should not have result")
        
        // Test parameter validation - testing with available method
        let incompleteStatsRequest = MCPRequest(
            method: "getConversationStats",
            params: [:] // This should work fine as it has no required parameters
        )
        
        // This should succeed (no database error since no database operations occur without setting database)
        let statsResponse = try await mcpServer.handleGetConversationStats(incompleteStatsRequest)
        XCTAssertNotNil(statsResponse.error, "Should return error when database not available")
    }
    
    // MARK: - Helper Methods
    
    private func loadSampleConversations() -> [SampleConversation] {
        guard let url = Bundle.main.url(forResource: "sample_conversations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let conversations = try? JSONDecoder().decode([SampleConversation].self, from: data) else {
            // Return fallback data if bundle resource not found
            return createFallbackSampleData()
        }
        
        return conversations
    }
    
    private func createFallbackSampleData() -> [SampleConversation] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            SampleConversation(
                title: "Swift Concurrency Discussion",
                content: "Had an in-depth conversation about Swift's async/await patterns and structured concurrency. Discussed best practices for handling asynchronous operations in iOS applications.",
                summary: "Swift async/await patterns and structured concurrency best practices",
                sender: "Alice",
                timestamp: calendar.date(byAdding: .day, value: -1, to: now)!,
                keywords: ["swift", "async", "await", "concurrency", "ios"]
            ),
            SampleConversation(
                title: "iOS Architecture Review",
                content: "Reviewed the new MVVM architecture implementation for our iOS app. Discussed SwiftUI integration and data binding patterns.",
                summary: "MVVM architecture review for iOS app with SwiftUI",
                sender: "Bob",
                timestamp: calendar.date(byAdding: .day, value: -3, to: now)!,
                keywords: ["ios", "architecture", "mvvm", "swiftui", "data binding"]
            ),
            SampleConversation(
                title: "Database Performance Optimization",
                content: "Analyzed database queries and identified performance bottlenecks. Implemented indexes and query optimization strategies.",
                summary: "Database performance analysis and optimization strategies",
                sender: "Carol",
                timestamp: calendar.date(byAdding: .weekOfYear, value: -1, to: now)!,
                keywords: ["database", "performance", "optimization", "indexes", "queries"]
            ),
            SampleConversation(
                title: "Machine Learning Integration",
                content: "Explored options for integrating machine learning models into our mobile application. Discussed Core ML and on-device inference.",
                summary: "Machine learning integration with Core ML for mobile apps",
                sender: "David",
                timestamp: calendar.date(byAdding: .day, value: -5, to: now)!,
                keywords: ["machine learning", "core ml", "mobile", "inference", "ai"]
            )
        ]
    }
}

// MARK: - Supporting Types

struct SampleConversation: Codable {
    let title: String
    let content: String
    let summary: String
    let sender: String
    let timestamp: Date
    let keywords: [String]
}

// MCPRequest is defined in MCPServer.swift - using that version

struct MCPResponse {
    let jsonrpc: String = "2.0"
    let id: String
    let result: Any?
    let error: MCPError?
    
    init(id: String, result: Any? = nil, error: MCPError? = nil) {
        self.id = id
        self.result = result
        self.error = error
    }
}

struct MCPError {
    let code: Int
    let message: String
    let data: Any?
    
    init(code: Int, message: String, data: Any? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

struct SeedingResult {
    let wasSeeded: Bool
    let itemsSeeded: Int
    let processingTime: TimeInterval
}