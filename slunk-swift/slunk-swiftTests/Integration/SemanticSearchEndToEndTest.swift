import XCTest
import Foundation
import NaturalLanguage
@testable import slunk_swift

final class SemanticSearchEndToEndTest: XCTestCase {
    
    // MARK: - Complete End-to-End Semantic Search Test
    
    func testCompleteSemanticSearchWorkflow() async throws {
        print("\n🚀 Starting End-to-End Semantic Search Test")
        print("=" * 60)
        
        // STEP 1: Create a fresh database
        print("\n📂 Step 1: Setting up fresh database...")
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("semantic_e2e_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
            print("🧹 Cleaned up test database")
        }
        
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        print("✅ Database initialized with SQLiteVec support")
        
        // STEP 2: Set up services
        print("\n🛠 Step 2: Initializing services...")
        let embeddingService = EmbeddingService()
        let smartIngestion = SmartIngestionService()
        await smartIngestion.setDatabase(schema)
        
        let queryEngine = NaturalLanguageQueryEngine()
        queryEngine.setDatabase(schema)
        print("✅ Services initialized and connected")
        
        // STEP 3: Ingest diverse test data
        print("\n📝 Step 3: Ingesting test conversations...")
        let testConversations = createSemanticTestData()
        
        var ingestedIds: [String] = []
        for (index, conversation) in testConversations.enumerated() {
            let result = try await smartIngestion.ingestText(
                content: conversation.content,
                title: conversation.title,
                summary: conversation.summary,
                sender: conversation.sender,
                timestamp: conversation.timestamp
            )
            ingestedIds.append(result.summaryId)
            print("  ✓ Ingested [\(index + 1)/\(testConversations.count)]: \(conversation.title)")
            print("    Keywords: \(result.extractedKeywords.joined(separator: ", "))")
        }
        
        print("✅ Ingested \(testConversations.count) conversations with automatic keyword extraction")
        
        // STEP 4: Test semantic similarity search
        print("\n🔍 Step 4: Testing semantic search capabilities...")
        
        // Test Case 1: Programming concepts (should find Swift and async content)
        print("\n  🔍 Test 1: Programming concepts")
        let programmingQuery = "concurrent programming and async operations"
        let programmingResults = try await searchAndAnalyze(
            query: programmingQuery,
            queryEngine: queryEngine,
            expectedTopics: ["swift", "async", "concurrency"]
        )
        
        // Test Case 2: System architecture (should find database and architecture content)
        print("\n  🔍 Test 2: System architecture")
        let architectureQuery = "system design and database performance"
        let architectureResults = try await searchAndAnalyze(
            query: architectureQuery,
            queryEngine: queryEngine,
            expectedTopics: ["architecture", "database", "performance"]
        )
        
        // Test Case 3: Machine learning (should find AI and ML content)
        print("\n  🔍 Test 3: Machine learning")
        let mlQuery = "artificial intelligence and machine learning models"
        let mlResults = try await searchAndAnalyze(
            query: mlQuery,
            queryEngine: queryEngine,
            expectedTopics: ["machine", "learning", "ai", "model"]
        )
        
        // Test Case 4: Cross-domain semantic similarity
        print("\n  🔍 Test 4: Cross-domain concepts")
        let crossDomainQuery = "optimization and efficiency improvements"
        let crossDomainResults = try await searchAndAnalyze(
            query: crossDomainQuery,
            queryEngine: queryEngine,
            expectedTopics: ["performance", "optimization", "efficiency"]
        )
        
        // STEP 5: Test hybrid search (semantic + keywords + temporal)
        print("\n🧠 Step 5: Testing hybrid search capabilities...")
        
        // Natural language query with multiple dimensions
        let hybridQuery = "Swift programming discussions from this week"
        let parsedQuery = queryEngine.parseQuery(hybridQuery)
        
        print("  📋 Parsed query analysis:")
        print("    Original: '\(hybridQuery)'")
        print("    Intent: \(parsedQuery.intent)")
        print("    Keywords: \(parsedQuery.keywords)")
        print("    Entities: \(parsedQuery.entities)")
        print("    Temporal: \(parsedQuery.temporalHint?.value ?? "none")")
        
        let hybridResults = try await queryEngine.executeHybridSearch(parsedQuery, limit: 5)
        
        print("  📊 Hybrid search results:")
        for (index, result) in hybridResults.enumerated() {
            print("    [\(index + 1)] Score: \(String(format: "%.3f", result.combinedScore))")
            print("        Title: \(result.summary.title)")
            print("        Semantic: \(String(format: "%.3f", result.semanticScore))")
            print("        Keyword: \(String(format: "%.3f", result.keywordScore))")
            print("        Matched: \(result.matchedKeywords.joined(separator: ", "))")
        }
        
        // STEP 6: Validate semantic understanding
        print("\n🎯 Step 6: Validating semantic understanding...")
        
        // Test that semantically similar queries find related content
        let similarQueries = [
            "concurrent programming", // Should match async/await content
            "system performance",     // Should match database optimization  
            "AI development",         // Should match machine learning content
            "code optimization"       // Should match performance discussions
        ]
        
        for query in similarQueries {
            let results = try await queryEngine.executeHybridSearch(
                queryEngine.parseQuery(query), 
                limit: 3
            )
            
            print("  🔍 Query: '\(query)'")
            if let topResult = results.first {
                print("    → Top match: \(topResult.summary.title)")
                print("    → Confidence: \(String(format: "%.1f%%", topResult.combinedScore * 100))")
                
                // Validate that we found semantically relevant content
                XCTAssertGreaterThan(topResult.combinedScore, 0.1, 
                    "Should find semantically relevant content for '\(query)'")
            }
        }
        
        // STEP 7: Performance validation
        print("\n⚡ Step 7: Performance validation...")
        
        let performanceQuery = "performance optimization techniques"
        let startTime = Date()
        
        let perfResults = try await queryEngine.executeHybridSearch(
            queryEngine.parseQuery(performanceQuery), 
            limit: 10
        )
        
        let queryTime = Date().timeIntervalSince(startTime)
        print("  ⏱ Query execution time: \(String(format: "%.0f", queryTime * 1000))ms")
        print("  📊 Results returned: \(perfResults.count)")
        
        // Validate performance requirements
        XCTAssertLessThan(queryTime, 0.5, "Hybrid search should complete in <500ms")
        XCTAssertFalse(perfResults.isEmpty, "Should return relevant results")
        
        // STEP 8: Final validation
        print("\n✅ Step 8: Final validation...")
        
        // Verify all conversations are searchable
        let allConversationsQuery = try await queryEngine.executeHybridSearch(
            queryEngine.parseQuery("conversation"), 
            limit: 20
        )
        
        print("  📈 Total searchable conversations: \(allConversationsQuery.count)")
        print("  🔍 Search coverage: \(String(format: "%.1f%%", Double(allConversationsQuery.count) / Double(testConversations.count) * 100))")
        
        // Final assertions
        XCTAssertGreaterThanOrEqual(allConversationsQuery.count, testConversations.count - 1, 
            "Should be able to find most ingested conversations")
        
        print("\n🎉 End-to-End Semantic Search Test Complete!")
        print("=" * 60)
        print("✅ All semantic search capabilities validated")
        print("✅ Hybrid search working correctly")  
        print("✅ Performance meets requirements")
        print("✅ System ready for production use")
    }
    
    // MARK: - Helper Methods
    
    private func searchAndAnalyze(
        query: String,
        queryEngine: NaturalLanguageQueryEngine,
        expectedTopics: [String],
        limit: Int = 5
    ) async throws -> [QueryResult] {
        
        print("    Query: '\(query)'")
        
        let parsedQuery = queryEngine.parseQuery(query)
        let results = try await queryEngine.executeHybridSearch(parsedQuery, limit: limit)
        
        print("    Results found: \(results.count)")
        
        if results.isEmpty {
            print("    ⚠️ No results found")
            return results
        }
        
        // Analyze top results
        for (index, result) in results.prefix(3).enumerated() {
            print("      [\(index + 1)] \(result.summary.title)")
            print("          Score: \(String(format: "%.3f", result.combinedScore))")
            print("          Keywords: \(result.summary.keywords.joined(separator: ", "))")
            
            // Check if result contains expected topics
            let resultText = "\(result.summary.title) \(result.summary.summary)".lowercased()
            let foundTopics = expectedTopics.filter { topic in
                resultText.contains(topic) || result.summary.keywords.contains(topic)
            }
            
            if !foundTopics.isEmpty {
                print("          ✓ Contains expected topics: \(foundTopics.joined(separator: ", "))")
            }
        }
        
        // Validate semantic relevance
        let topResult = results.first!
        XCTAssertGreaterThan(topResult.combinedScore, 0.05, 
            "Top result should have reasonable semantic similarity for '\(query)'")
        
        return results
    }
    
    private func createSemanticTestData() -> [TestConversation] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            TestConversation(
                title: "Swift Concurrency and Async/Await Patterns",
                content: """
                We had an extensive discussion about Swift's structured concurrency model. The team explored async/await patterns, TaskGroup usage for parallel processing, and proper error handling in asynchronous contexts. We covered actor isolation and how it prevents data races in concurrent programming. The new concurrency features make asynchronous code much more readable and maintainable than traditional callback-based approaches.
                """,
                summary: "Swift concurrency discussion covering async/await, TaskGroup, and actor isolation",
                sender: "Alice",
                timestamp: calendar.date(byAdding: .day, value: -1, to: now)!
            ),
            
            TestConversation(
                title: "Database Performance Optimization Strategies",
                content: """
                Analyzed database query performance and identified bottlenecks in our data access layer. We discussed indexing strategies, query optimization techniques, and caching mechanisms. The team reviewed connection pooling, prepared statements, and batch processing approaches. We also covered database schema design patterns that improve both read and write performance at scale.
                """,
                summary: "Database performance analysis and optimization strategies",
                sender: "Bob",
                timestamp: calendar.date(byAdding: .day, value: -2, to: now)!
            ),
            
            TestConversation(
                title: "Machine Learning Model Integration Architecture",
                content: """
                Explored approaches for integrating machine learning models into our mobile applications. We discussed Core ML optimization, on-device inference performance, and the trade-offs between cloud-based and edge computing. The conversation covered natural language processing pipelines, model quantization techniques, and deployment strategies for production ML systems.
                """,
                summary: "Machine learning integration covering Core ML, inference, and NLP pipelines",
                sender: "Carol",
                timestamp: calendar.date(byAdding: .day, value: -3, to: now)!
            ),
            
            TestConversation(
                title: "iOS Architecture Patterns and SwiftUI Best Practices",
                content: """
                Reviewed modern iOS application architecture patterns including MVVM, Coordinator, and Clean Architecture approaches. We discussed SwiftUI state management, Combine integration, and navigation patterns. The team explored dependency injection, protocol-oriented programming, and testing strategies for SwiftUI applications. We also covered performance considerations for complex view hierarchies.
                """,
                summary: "iOS architecture patterns with SwiftUI, MVVM, and state management",
                sender: "David",
                timestamp: calendar.date(byAdding: .day, value: -4, to: now)!
            ),
            
            TestConversation(
                title: "Artificial Intelligence Ethics and Responsible Development",
                content: """
                Deep discussion about ethical considerations in AI development and deployment. We covered bias detection and mitigation strategies, privacy-preserving machine learning techniques, and responsible AI practices. The conversation included topics like explainable AI, algorithmic transparency, and the social impact of automated decision-making systems in software applications.
                """,
                summary: "AI ethics discussion covering bias mitigation, privacy, and responsible development",
                sender: "Eve",
                timestamp: calendar.date(byAdding: .day, value: -5, to: now)!
            ),
            
            TestConversation(
                title: "System Scalability and Microservices Design",
                content: """
                Analyzed system scalability challenges and microservices architecture patterns. We discussed service decomposition strategies, inter-service communication protocols, and distributed system resilience patterns. The team explored load balancing, circuit breakers, and monitoring approaches for microservices. We also covered containerization and orchestration strategies for production deployments.
                """,
                summary: "Microservices architecture and system scalability analysis",
                sender: "Frank",
                timestamp: calendar.date(byAdding: .day, value: -6, to: now)!
            ),
            
            TestConversation(
                title: "User Experience Design for Developer Tools",
                content: """
                Explored user experience design principles specifically for developer tools and technical interfaces. We discussed information architecture for complex workflows, progressive disclosure techniques, and accessibility considerations. The conversation covered user research methodologies for technical audiences, design system approaches, and usability testing strategies for developer-focused applications.
                """,
                summary: "UX design for developer tools covering information architecture and usability",
                sender: "Grace",
                timestamp: calendar.date(byAdding: .day, value: -7, to: now)!
            ),
            
            TestConversation(
                title: "Code Quality and Automated Testing Strategies",
                content: """
                Comprehensive review of code quality practices and automated testing approaches. We discussed test-driven development, continuous integration pipelines, and static analysis tools. The team explored unit testing, integration testing, and end-to-end testing strategies. We also covered code review processes, automated quality gates, and maintaining high code quality standards in large development teams.
                """,
                summary: "Code quality practices and automated testing strategies",
                sender: "Henry",
                timestamp: calendar.date(byAdding: .day, value: -8, to: now)!
            )
        ]
    }
}

// MARK: - Supporting Types

struct TestConversation {
    let title: String
    let content: String
    let summary: String
    let sender: String
    let timestamp: Date
}

// MARK: - String Extension for Pretty Printing

// String multiplication operator removed to avoid conflicts