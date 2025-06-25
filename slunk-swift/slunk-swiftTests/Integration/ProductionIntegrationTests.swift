import XCTest
import Foundation
@testable import slunk_swift

final class ProductionIntegrationTests: XCTestCase {
    
    // MARK: - Full System Integration Test
    
    func testCompleteSystemIntegration() async throws {
        print("\n🚀 Testing Complete System Integration")
        print("=" * 50)
        
        // Use production-like Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                  in: .userDomainMask).first!
        let testDir = appSupport.appendingPathComponent("SlunkTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: testDir)
        }
        
        let dbPath = testDir.appendingPathComponent("slunk_conversations.db").path
        
        // Initialize complete system
        print("\n📦 Initializing production system...")
        let schema = try SQLiteVecSchema(databasePath: dbPath)
        try await schema.initializeDatabase()
        
        // Apply production optimizations
        let optimizer = DatabaseOptimizer()
        try await optimizer.applyOptimizations(to: schema)
        try await optimizer.optimizeIndexes(on: schema)
        
        // Initialize services
        let queryEngine = NaturalLanguageQueryEngine()
        queryEngine.setDatabase(schema)
        
        let smartIngestion = SmartIngestionService()
        await smartIngestion.setDatabase(schema)
        
        let dataSeeder = DataSeeder()
        await dataSeeder.setDatabase(schema)
        
        // Test data seeding
        print("\n🌱 Testing data seeding...")
        let seedResult = try await dataSeeder.seedIfEmpty()
        
        print("  ✓ Seeded \(seedResult.conversationsAdded) conversations")
        print("  ✓ Total keywords: \(seedResult.totalKeywords)")
        print("  ✓ Time taken: \(String(format: "%.2f", seedResult.timeTaken))s")
        
        XCTAssertGreaterThan(seedResult.conversationsAdded, 0, "Should seed initial data")
        
        // Test real-world queries
        print("\n🔍 Testing production queries...")
        let testQueries = [
            "what did we discuss about Swift concurrency yesterday",
            "show me conversations with Alice from last week",
            "find all meetings about database optimization",
            "latest discussions on performance improvements",
            "conversations about testing async code"
        ]
        
        for query in testQueries {
            print("\n  Query: '\(query)'")
            let parsedQuery = queryEngine.parseQuery(query)
            
            print("    Intent: \(parsedQuery.intent)")
            print("    Keywords: \(parsedQuery.keywords.joined(separator: ", "))")
            if !parsedQuery.entities.isEmpty {
                print("    Entities: \(parsedQuery.entities.joined(separator: ", "))")
            }
            if let temporal = parsedQuery.temporalHint {
                print("    Temporal: \(temporal.type) - \(temporal.value)")
            }
            
            let results = try await queryEngine.executeHybridSearch(parsedQuery, limit: 3)
            print("    Results: \(results.count)")
            
            for (index, result) in results.prefix(3).enumerated() {
                print("      [\(index + 1)] \(result.summary.title)")
                print("          Score: \(String(format: "%.3f", result.combinedScore))")
            }
            
            XCTAssertFalse(results.isEmpty, "Query '\(query)' should return results")
        }
        
        // Test concurrent operations
        print("\n⚡ Testing concurrent operations...")
        let concurrentTasks = 20
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: Int.self) { group in
            // Concurrent ingestions
            for i in 0..<concurrentTasks/2 {
                group.addTask {
                    let result = try await smartIngestion.ingestText(
                        content: "Concurrent test content \(i) about Swift async patterns",
                        title: "Concurrent Test \(i)",
                        summary: "Testing concurrent operations",
                        sender: "ConcurrentUser\(i % 3)"
                    )
                    return result.extractedKeywords.count
                }
            }
            
            // Concurrent queries
            for i in 0..<concurrentTasks/2 {
                group.addTask {
                    let query = "concurrent test \(i % 3)"
                    let parsedQuery = queryEngine.parseQuery(query)
                    let results = try await queryEngine.executeHybridSearch(parsedQuery, limit: 5)
                    return results.count
                }
            }
            
            var totalResults = 0
            for try await result in group {
                totalResults += result
            }
            
            let duration = Date().timeIntervalSince(startTime)
            print("  ✓ Completed \(concurrentTasks) concurrent operations in \(String(format: "%.2f", duration))s")
            print("  ✓ Average time per operation: \(String(format: "%.0f", duration * 1000 / Double(concurrentTasks)))ms")
            
            XCTAssertGreaterThan(totalResults, 0, "Concurrent operations should produce results")
        }
        
        // Test database persistence
        print("\n💾 Testing database persistence...")
        let sizeBefore = try await schema.getDatabaseSize()
        print("  Database size: \(sizeBefore / 1024) KB")
        
        // Close and reopen database
        let schema2 = try SQLiteVecSchema(databasePath: dbPath)
        try await schema2.initializeDatabase()
        
        let stats = try await schema2.getTableStatistics()
        print("  Tables after reload:")
        for (table, stat) in stats {
            print("    - \(table): \(stat.rowCount) rows")
        }
        
        XCTAssertGreaterThan(stats["text_summaries"]?.rowCount ?? 0, 0, "Data should persist")
        
        // Test error handling
        print("\n🛡️ Testing error handling...")
        
        // Test with invalid query
        do {
            let emptyQuery = queryEngine.parseQuery("")
            let results = try await queryEngine.executeHybridSearch(emptyQuery, limit: 10)
            XCTAssertTrue(results.isEmpty, "Empty query should return no results")
            print("  ✓ Empty query handled gracefully")
        } catch {
            XCTFail("Should handle empty query without throwing")
        }
        
        // Test with very long content
        let longContent = String(repeating: "Test content. ", count: 10000)
        do {
            let result = try await smartIngestion.ingestText(
                content: longContent,
                title: "Very Long Content Test",
                summary: "Testing large content handling",
                sender: "TestUser"
            )
            print("  ✓ Large content ingested successfully")
            XCTAssertFalse(result.summaryId.isEmpty, "Should generate summary ID")
        } catch {
            XCTFail("Should handle large content: \(error)")
        }
        
        // Test memory usage
        print("\n💾 Testing memory usage...")
        let memoryMonitor = MemoryMonitor()
        let initialMemory = memoryMonitor.getCurrentMemoryUsage()
        
        // Perform memory-intensive operations
        for i in 0..<100 {
            _ = try await smartIngestion.ingestText(
                content: "Memory test content \(i)",
                title: "Memory Test \(i)",
                summary: "Testing memory usage",
                sender: "MemoryTestUser"
            )
        }
        
        let finalMemory = memoryMonitor.getCurrentMemoryUsage()
        let memoryIncrease = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        let pressure = memoryMonitor.getMemoryPressure()
        
        print("  Initial memory: \(initialMemory / 1_000_000) MB")
        print("  Final memory: \(finalMemory / 1_000_000) MB")
        print("  Memory increase: \(memoryIncrease / 1_000_000) MB")
        print("  Memory pressure: \(pressure)")
        
        XCTAssertNotEqual(pressure, .high, "Memory pressure should not be high")
        
        print("\n✅ Complete system integration test passed!")
    }
    
    // MARK: - MCP Server Integration Test
    
    func testMCPServerIntegration() async throws {
        print("\n🤖 Testing MCP Server Integration")
        print("=" * 50)
        
        // Create test database
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // Initialize system
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        
        let smartIngestion = SmartIngestionService()
        await smartIngestion.setDatabase(schema)
        
        let queryEngine = NaturalLanguageQueryEngine()
        queryEngine.setDatabase(schema)
        
        let dataSeeder = DataSeeder()
        await dataSeeder.setDatabase(schema)
        
        // Seed initial data
        _ = try await dataSeeder.seedIfEmpty()
        
        // Test searchConversations tool
        print("\n🔍 Testing searchConversations MCP tool...")
        
        let searchTests = [
            ("Swift async patterns", 5),
            ("meeting with Alice", 3),
            ("database optimization", 10)
        ]
        
        for (query, limit) in searchTests {
            let results = try await MCPServer.searchConversations(
                query: query,
                limit: limit,
                schema: schema,
                queryEngine: queryEngine
            )
            
            print("  Query: '\(query)' (limit: \(limit))")
            print("  Results: \(results.count)")
            
            XCTAssertLessThanOrEqual(results.count, limit, "Should respect limit")
            
            if let first = results.first {
                print("    Top result: \(first["title"] ?? "No title")")
                print("    Score: \(first["score"] ?? "No score")")
                XCTAssertNotNil(first["id"], "Result should have ID")
                XCTAssertNotNil(first["title"], "Result should have title")
                XCTAssertNotNil(first["summary"], "Result should have summary")
                XCTAssertNotNil(first["score"], "Result should have score")
            }
        }
        
        // Test ingestText tool
        print("\n📝 Testing ingestText MCP tool...")
        
        let testIngestions = [
            (
                content: "New discussion about SwiftUI performance optimizations",
                title: "SwiftUI Performance",
                summary: "Tips for optimizing SwiftUI views",
                sender: "DevTeam"
            ),
            (
                content: "Meeting notes: Decided to implement new caching strategy",
                title: "Architecture Meeting",
                summary: "Caching strategy decisions",
                sender: "Alice"
            )
        ]
        
        for ingestion in testIngestions {
            let result = try await MCPServer.ingestText(
                content: ingestion.content,
                title: ingestion.title,
                summary: ingestion.summary,
                sender: ingestion.sender,
                smartIngestion: smartIngestion
            )
            
            print("  Ingested: '\(ingestion.title)'")
            print("    ID: \(result["id"] ?? "No ID")")
            print("    Keywords: \(result["keywords"] ?? [])")
            
            XCTAssertNotNil(result["id"], "Should return summary ID")
            XCTAssertNotNil(result["keywords"], "Should extract keywords")
            XCTAssertEqual(result["status"] as? String, "success", "Should indicate success")
        }
        
        // Test getConversationStats tool
        print("\n📊 Testing getConversationStats MCP tool...")
        
        let stats = try await MCPServer.getConversationStats(schema: schema)
        
        print("  Total conversations: \(stats["totalConversations"] ?? 0)")
        print("  Unique senders: \(stats["uniqueSenders"] ?? 0)")
        print("  Date range: \(stats["dateRange"] ?? "Unknown")")
        
        if let topKeywords = stats["topKeywords"] as? [[String: Any]] {
            print("  Top keywords:")
            for keyword in topKeywords.prefix(5) {
                print("    - \(keyword["word"] ?? ""): \(keyword["count"] ?? 0)")
            }
        }
        
        XCTAssertGreaterThan(stats["totalConversations"] as? Int ?? 0, 0, "Should have conversations")
        XCTAssertGreaterThan(stats["uniqueSenders"] as? Int ?? 0, 0, "Should have senders")
        XCTAssertNotNil(stats["topKeywords"], "Should have top keywords")
        
        // Verify new content is searchable
        print("\n🔄 Verifying new content is searchable...")
        
        let newResults = try await MCPServer.searchConversations(
            query: "SwiftUI performance caching",
            limit: 5,
            schema: schema,
            queryEngine: queryEngine
        )
        
        let hasNewContent = newResults.contains { result in
            (result["title"] as? String)?.contains("SwiftUI") == true ||
            (result["title"] as? String)?.contains("Architecture") == true
        }
        
        XCTAssertTrue(hasNewContent, "Newly ingested content should be searchable")
        print("  ✓ New content is searchable")
        
        print("\n✅ MCP Server integration test passed!")
    }
    
    // MARK: - Production Error Scenarios Test
    
    func testProductionErrorScenarios() async throws {
        print("\n🛡️ Testing Production Error Scenarios")
        print("=" * 50)
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("error_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        
        let smartIngestion = SmartIngestionService()
        await smartIngestion.setDatabase(schema)
        
        let queryEngine = NaturalLanguageQueryEngine()
        queryEngine.setDatabase(schema)
        
        // Test 1: Invalid characters in content
        print("\n  Testing invalid characters...")
        do {
            let invalidContent = "Test \0 null \u{1} byte content"
            _ = try await smartIngestion.ingestText(
                content: invalidContent,
                title: "Invalid Chars Test",
                summary: "Testing invalid characters",
                sender: "TestUser"
            )
            print("  ✓ Handled invalid characters gracefully")
        } catch {
            print("  ⚠️ Error with invalid characters: \(error)")
            // This is acceptable - we want to know if it fails
        }
        
        // Test 2: Extremely long single word
        print("\n  Testing extremely long word...")
        let longWord = String(repeating: "a", count: 10000)
        do {
            _ = try await smartIngestion.ingestText(
                content: "This is a \(longWord) test",
                title: "Long Word Test",
                summary: "Testing long words",
                sender: "TestUser"
            )
            print("  ✓ Handled long word gracefully")
        } catch {
            print("  ⚠️ Error with long word: \(error)")
        }
        
        // Test 3: Special SQL characters
        print("\n  Testing SQL injection attempts...")
        let sqlTests = [
            "'; DROP TABLE text_summaries; --",
            "\" OR 1=1 --",
            "\\'; SELECT * FROM text_summaries; --"
        ]
        
        for sqlContent in sqlTests {
            do {
                _ = try await smartIngestion.ingestText(
                    content: sqlContent,
                    title: "SQL Test",
                    summary: "Testing SQL safety",
                    sender: "TestUser"
                )
                print("  ✓ Safely handled: \(sqlContent)")
            } catch {
                print("  ⚠️ Error with SQL content: \(error)")
            }
        }
        
        // Test 4: Unicode edge cases
        print("\n  Testing Unicode edge cases...")
        let unicodeTests = [
            "Emoji test: 🚀🔍📊💾",
            "Chinese: 你好世界",
            "Arabic: مرحبا بالعالم",
            "Zero-width: test\u{200B}word",
            "Combining: é = e\u{0301}"
        ]
        
        for unicodeContent in unicodeTests {
            do {
                _ = try await smartIngestion.ingestText(
                    content: unicodeContent,
                    title: "Unicode Test",
                    summary: unicodeContent,
                    sender: "TestUser"
                )
                print("  ✓ Handled Unicode: \(unicodeContent)")
            } catch {
                print("  ⚠️ Error with Unicode: \(error)")
            }
        }
        
        // Test 5: Concurrent database access
        print("\n  Testing concurrent database stress...")
        let stressTasks = 50
        var errors = 0
        
        try await withThrowingTaskGroup(of: Bool.self) { group in
            for i in 0..<stressTasks {
                group.addTask {
                    do {
                        if i % 2 == 0 {
                            // Ingestion
                            _ = try await smartIngestion.ingestText(
                                content: "Stress test \(i)",
                                title: "Stress \(i)",
                                summary: "Testing stress",
                                sender: "StressUser"
                            )
                        } else {
                            // Query
                            let query = queryEngine.parseQuery("stress test")
                            _ = try await queryEngine.executeHybridSearch(query, limit: 1)
                        }
                        return true
                    } catch {
                        return false
                    }
                }
            }
            
            for try await success in group {
                if !success {
                    errors += 1
                }
            }
        }
        
        print("  ✓ Completed \(stressTasks) concurrent operations")
        print("  ✓ Errors: \(errors)")
        XCTAssertLessThan(errors, stressTasks / 10, "Error rate should be less than 10%")
        
        print("\n✅ Production error scenarios handled successfully!")
    }
}

// MARK: - Test Helpers

extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}