import XCTest
import Foundation
import NaturalLanguage
@testable import slunk_swift

final class NaturalLanguageQueryTests: XCTestCase {
    
    // MARK: - Query Parsing Tests
    
    func testQueryParsing() {
        let engine = NaturalLanguageQueryEngine()
        
        // Test "Swift conversations from last week" → structured query
        let query1 = "Show me Swift conversations from last week"
        let parsed1 = engine.parseQuery(query1)
        
        XCTAssertTrue(parsed1.keywords.contains("swift"), "Should extract 'swift' as keyword")
        XCTAssertTrue(parsed1.keywords.contains("conversations"), "Should extract 'conversations' as keyword")
        XCTAssertNotNil(parsed1.temporalHint, "Should detect temporal hint")
        XCTAssertEqual(parsed1.intent, .search, "Should identify search intent")
        
        // Test temporal hint extraction (\"yesterday\", \"last month\")
        let query2 = "Find documents about iOS development from yesterday"
        let parsed2 = engine.parseQuery(query2)
        
        XCTAssertTrue(parsed2.keywords.contains("ios"), "Should extract 'ios' as keyword")
        XCTAssertTrue(parsed2.keywords.contains("development"), "Should extract 'development' as keyword")
        XCTAssertEqual(parsed2.temporalHint?.type, .relative, "Should detect relative temporal hint")
        XCTAssertEqual(parsed2.temporalHint?.value, "yesterday", "Should extract 'yesterday'")
        
        // Test entity extraction (names, topics)
        let query3 = "Show planning meetings with Alice from June"
        let parsed3 = engine.parseQuery(query3)
        
        XCTAssertTrue(parsed3.entities.contains("alice"), "Should extract 'Alice' as entity")
        XCTAssertTrue(parsed3.keywords.contains("planning"), "Should extract 'planning' as keyword")
        XCTAssertTrue(parsed3.keywords.contains("meetings"), "Should extract 'meetings' as keyword")
        XCTAssertEqual(parsed3.temporalHint?.value, "june", "Should extract 'June' as temporal hint")
    }
    
    func testHybridSearch() async throws {
        let engine = NaturalLanguageQueryEngine()
        
        // Create temporary database with test data
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("hybrid_search_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        engine.setDatabase(schema)
        
        // Create test summaries with different characteristics
        let testSummaries = [
            // Swift-related content
            TestSummary(
                title: "Swift Async/Await Tutorial",
                content: "Learn about Swift's new async/await syntax for better concurrency",
                summary: "Swift async/await concurrency tutorial",
                keywords: ["swift", "async", "await", "concurrency"],
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date())! // Yesterday
            ),
            // iOS development content  
            TestSummary(
                title: "iOS App Architecture",
                content: "Best practices for iOS application architecture and design patterns",
                summary: "iOS app architecture best practices",
                keywords: ["ios", "architecture", "design", "patterns"],
                timestamp: Calendar.current.date(byAdding: .day, value: -7, to: Date())! // Last week
            ),
            // Unrelated content
            TestSummary(
                title: "Cooking Recipes",
                content: "Delicious pasta recipes from Italy with traditional ingredients",
                summary: "Italian pasta cooking recipes",
                keywords: ["cooking", "pasta", "italy", "recipes"],
                timestamp: Calendar.current.date(byAdding: .day, value: -2, to: Date())! // 2 days ago
            )
        ]
        
        // Store test data
        let embeddingService = EmbeddingService()
        for testSummary in testSummaries {
            let summary = TextSummary(
                title: testSummary.title,
                content: testSummary.content,
                summary: testSummary.summary,
                timestamp: testSummary.timestamp,
                keywords: testSummary.keywords
            )
            
            do {
                let embedding = try await embeddingService.generateEmbedding(for: summary.summary)
                try await schema.storeSummaryWithEmbedding(summary, embedding: embedding)
            } catch {
                XCTFail("Failed to generate embedding: \(error)")
                continue
            }
        }
        
        // Test semantic similarity using existing vector search
        let query = ParsedQuery(
            originalText: "Swift programming tutorials",
            intent: .search,
            keywords: ["swift", "programming", "tutorials"],
            entities: [],
            temporalHint: nil
        )
        
        let results = try await engine.executeHybridSearch(query, limit: 3)
        XCTAssertFalse(results.isEmpty, "Should find search results")
        
        // Swift-related content should rank higher
        let swiftResults = results.filter { $0.summary.title.lowercased().contains("swift") }
        XCTAssertFalse(swiftResults.isEmpty, "Should find Swift-related content")
        
        // Test keyword matching using SQLite JSON operators
        let keywordQuery = ParsedQuery(
            originalText: "iOS architecture",
            intent: .search,
            keywords: ["ios", "architecture"],
            entities: [],
            temporalHint: nil
        )
        
        let keywordResults = try await engine.executeHybridSearch(keywordQuery, limit: 3)
        XCTAssertFalse(keywordResults.isEmpty, "Should find keyword matches")
        
        // Test temporal filtering using date indexes
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let temporalQuery = ParsedQuery(
            originalText: "recent Swift content",
            intent: .search,
            keywords: ["swift"],
            entities: [],
            temporalHint: TemporalHint(type: .relative, value: "yesterday", resolvedDate: yesterday)
        )
        
        let temporalResults = try await engine.executeHybridSearch(temporalQuery, limit: 3)
        XCTAssertFalse(temporalResults.isEmpty, "Should find temporal matches")
        
        // Test combined scoring algorithm
        for result in results {
            XCTAssertGreaterThan(result.combinedScore, 0.0, "Should have positive combined score")
            XCTAssertLessThanOrEqual(result.combinedScore, 1.0, "Combined score should not exceed 1.0")
        }
    }
    
    func testRealWorldQueries() async throws {
        let engine = NaturalLanguageQueryEngine()
        
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("real_world_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        engine.setDatabase(schema)
        
        // Create realistic test data
        let testData = [
            TestSummary(
                title: "Planning Meeting Notes",
                content: "Discussed Q3 goals with Alice and Bob. Focus on Swift migration project.",
                summary: "Q3 planning meeting with Alice and Bob about Swift migration",
                keywords: ["planning", "meeting", "q3", "goals", "swift", "migration"],
                timestamp: Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!
            ),
            TestSummary(
                title: "Performance Issues Report",
                content: "Identified memory leaks in the iOS app causing crashes during peak usage.",
                summary: "iOS app performance issues and memory leaks",
                keywords: ["performance", "ios", "memory", "leaks", "crashes"],
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date())! // Yesterday
            ),
            TestSummary(
                title: "Architecture Review",
                content: "Reviewed the new microservices architecture proposed by the engineering team.",
                summary: "Microservices architecture review",
                keywords: ["architecture", "microservices", "engineering", "review"],
                timestamp: Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())! // Last week
            )
        ]
        
        // Store test data
        let embeddingService = EmbeddingService()
        for testItem in testData {
            let summary = TextSummary(
                title: testItem.title,
                content: testItem.content,
                summary: testItem.summary,
                timestamp: testItem.timestamp,
                keywords: testItem.keywords
            )
            
            do {
                let embedding = try await embeddingService.generateEmbedding(for: summary.summary)
                try await schema.storeSummaryWithEmbedding(summary, embedding: embedding)
            } catch {
                continue
            }
        }
        
        // Test complex queries like \"planning meetings with Alice from June\"
        let complexQuery1 = "planning meetings with Alice from June"
        let parsed1 = engine.parseQuery(complexQuery1)
        let results1 = try await engine.executeHybridSearch(parsed1, limit: 5)
        
        XCTAssertFalse(results1.isEmpty, "Should find planning meeting results")
        
        // Should find the planning meeting with Alice
        let aliceMeetings = results1.filter { result in
            result.summary.content.lowercased().contains("alice") &&
            result.summary.keywords.contains("planning")
        }
        XCTAssertFalse(aliceMeetings.isEmpty, "Should find Alice's planning meeting")
        
        // Test \"performance issues yesterday\"
        let complexQuery2 = "performance issues yesterday"
        let parsed2 = engine.parseQuery(complexQuery2)
        let results2 = try await engine.executeHybridSearch(parsed2, limit: 5)
        
        XCTAssertFalse(results2.isEmpty, "Should find performance issue results")
        
        // Should find recent performance issues
        let performanceResults = results2.filter { result in
            result.summary.keywords.contains("performance")
        }
        XCTAssertFalse(performanceResults.isEmpty, "Should find performance-related content")
        
        // Test performance <200ms for hybrid queries
        let startTime = Date()
        let _ = try await engine.executeHybridSearch(parsed1, limit: 10)
        let queryTime = Date().timeIntervalSince(startTime)
        
        XCTAssertLessThan(queryTime, 0.2, "Hybrid queries should complete in <200ms")
    }
    
    func testQueryIntent() {
        let engine = NaturalLanguageQueryEngine()
        
        // Test search intent
        let searchQuery = "find documents about Swift"
        let searchParsed = engine.parseQuery(searchQuery)
        XCTAssertEqual(searchParsed.intent, .search, "Should detect search intent")
        
        // Test show intent
        let showQuery = "show me all iOS projects"
        let showParsed = engine.parseQuery(showQuery)
        XCTAssertEqual(showParsed.intent, .show, "Should detect show intent")
        
        // Test list intent
        let listQuery = "list recent conversations"
        let listParsed = engine.parseQuery(listQuery)
        XCTAssertEqual(listParsed.intent, .list, "Should detect list intent")
        
        // Test analyze intent
        let analyzeQuery = "analyze performance trends"
        let analyzeParsed = engine.parseQuery(analyzeQuery)
        XCTAssertEqual(analyzeParsed.intent, .analyze, "Should detect analyze intent")
    }
    
    func testTemporalHintExtraction() {
        let engine = NaturalLanguageQueryEngine()
        
        // Test relative dates
        let relativeQueries = [
            ("yesterday", "yesterday"),
            ("last week", "last week"),
            ("last month", "last month"),
            ("this morning", "this morning")
        ]
        
        for (input, expected) in relativeQueries {
            let query = "show me documents from \(input)"
            let parsed = engine.parseQuery(query)
            XCTAssertNotNil(parsed.temporalHint, "Should detect temporal hint for '\(input)'")
            XCTAssertEqual(parsed.temporalHint?.value, expected, "Should extract '\(expected)'")
            XCTAssertEqual(parsed.temporalHint?.type, .relative, "Should be relative temporal hint")
        }
        
        // Test absolute dates
        let absoluteQueries = [
            ("June 2024", "june 2024"),
            ("January 15", "january 15"),
            ("2024-06-15", "2024-06-15")
        ]
        
        for (input, expected) in absoluteQueries {
            let query = "find content from \(input)"
            let parsed = engine.parseQuery(query)
            XCTAssertNotNil(parsed.temporalHint, "Should detect temporal hint for '\(input)'")
            XCTAssertEqual(parsed.temporalHint?.value.lowercased(), expected, "Should extract '\(expected)'")
        }
    }
}

// MARK: - Test Helper Types

struct TestSummary {
    let title: String
    let content: String
    let summary: String
    let keywords: [String]
    let timestamp: Date
}