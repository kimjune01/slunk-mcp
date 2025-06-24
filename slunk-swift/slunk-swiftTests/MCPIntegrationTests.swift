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
        
        // Test searchConversations with natural language
        let searchRequest = MCPRequest(
            method: "searchConversations",
            params: [
                "query": "Swift programming",
                "limit": 5
            ]
        )
        
        let searchResponse = try await mcpServer.handleSearchConversations(searchRequest)
        XCTAssertNotNil(searchResponse.result, "Should return search results")
        
        if let results = searchResponse.result as? [[String: Any]] {
            XCTAssertFalse(results.isEmpty, "Should find Swift-related conversations")
            
            for result in results {
                XCTAssertNotNil(result["id"], "Result should have ID")
                XCTAssertNotNil(result["title"], "Result should have title")
                XCTAssertNotNil(result["summary"], "Result should have summary")
                XCTAssertNotNil(result["score"], "Result should have relevance score")
            }
        }
        
        // Test ingestText with automatic processing
        let ingestRequest = MCPRequest(
            method: "ingestText",
            params: [
                "content": "This is a test conversation about iOS development using SwiftUI framework.",
                "title": "iOS Development Chat",
                "summary": "Discussion about SwiftUI in iOS development",
                "sender": "TestUser"
            ]
        )
        
        let ingestResponse = try await mcpServer.handleIngestText(ingestRequest)
        XCTAssertNotNil(ingestResponse.result, "Should return ingestion result")
        
        if let result = ingestResponse.result as? [String: Any] {
            XCTAssertNotNil(result["id"], "Should return summary ID")
            XCTAssertNotNil(result["keywords"], "Should extract keywords")
        }
        
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
        
        // 1. Ingest some content
        let ingestRequest = MCPRequest(
            method: "ingestText",
            params: [
                "content": "Had a great meeting about Swift async/await patterns. Team discussed best practices for handling asynchronous operations in iOS apps.",
                "title": "Swift Async Meeting",
                "summary": "Meeting notes about Swift async/await patterns",
                "sender": "Alice"
            ]
        )
        
        let ingestResponse = try await mcpServer.handleIngestText(ingestRequest)
        XCTAssertEqual(ingestResponse.jsonrpc, "2.0", "Should be JSON-RPC 2.0 compliant")
        XCTAssertNotNil(ingestResponse.result, "Ingestion should succeed")
        
        // 2. Search for the content
        let searchRequest = MCPRequest(
            method: "searchConversations",
            params: [
                "query": "Swift async meeting with Alice",
                "limit": 10
            ]
        )
        
        let searchResponse = try await mcpServer.handleSearchConversations(searchRequest)
        XCTAssertEqual(searchResponse.jsonrpc, "2.0", "Should be JSON-RPC 2.0 compliant")
        XCTAssertNotNil(searchResponse.result, "Search should return results")
        
        if let results = searchResponse.result as? [[String: Any]] {
            XCTAssertFalse(results.isEmpty, "Should find the ingested content")
            
            let firstResult = results[0]
            let title = firstResult["title"] as? String
            XCTAssertTrue(title?.contains("Swift") == true, "Should find Swift-related content")
        }
        
        // 3. Get updated stats
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
        
        // Test parameter validation
        let incompleteRequest = MCPRequest(
            method: "ingestText",
            params: [:] // Missing required parameters
        )
        
        let paramErrorResponse = try await mcpServer.handleIngestText(incompleteRequest)
        XCTAssertNotNil(paramErrorResponse.error, "Should return error for missing parameters")
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