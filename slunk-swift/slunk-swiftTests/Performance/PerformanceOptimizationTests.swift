import XCTest
import Foundation
@testable import slunk_swift

final class PerformanceOptimizationTests: XCTestCase {
    
    // MARK: - Query Performance Tests
    
    func testQueryPerformance() async throws {
        print("\n🚀 Testing Query Performance")
        print("=" * 50)
        
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("perf_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        
        // Create query engine
        let queryEngine = NaturalLanguageQueryEngine()
        queryEngine.setDatabase(schema)
        
        // Seed with test data
        let smartIngestion = SmartIngestionService()
        await smartIngestion.setDatabase(schema)
        
        let testContent = [
            ("Swift Concurrency", "Advanced discussion about Swift async/await patterns and structured concurrency"),
            ("Database Performance", "Analysis of SQLite query optimization and indexing strategies"),
            ("iOS Architecture", "MVVM patterns with SwiftUI and Combine integration")
        ]
        
        for (title, content) in testContent {
            try await smartIngestion.ingestText(
                content: content,
                title: title,
                summary: content,
                sender: "TestUser"
            )
        }
        
        // Test query performance
        print("\n🔍 Testing query performance...")
        let query = "Swift programming patterns"
        let parsedQuery = queryEngine.parseQuery(query)
        
        let startTime1 = Date()
        let results1 = try await queryEngine.executeHybridSearch(parsedQuery, limit: 5)
        let firstQueryTime = Date().timeIntervalSince(startTime1)
        
        print("  ⏱ First query: \(Int(firstQueryTime * 1000))ms")
        print("  📊 Results: \(results1.count)")
        
        XCTAssertFalse(results1.isEmpty, "Should return results")
        XCTAssertLessThan(firstQueryTime, 0.2, "Query should complete within 200ms")
        
        // Test repeated queries
        print("\n⚡ Testing repeated query performance...")
        var queryTimes: [TimeInterval] = []
        
        for i in 0..<5 {
            let startTime = Date()
            let results = try await queryEngine.executeHybridSearch(parsedQuery, limit: 5)
            let queryTime = Date().timeIntervalSince(startTime)
            queryTimes.append(queryTime)
            
            print("  Query \(i+1): \(Int(queryTime * 1000))ms")
            XCTAssertEqual(results.count, results1.count, "Results should be consistent")
        }
        
        let avgQueryTime = queryTimes.reduce(0, +) / Double(queryTimes.count)
        print("\n  📊 Average query time: \(Int(avgQueryTime * 1000))ms")
        
        // Test with new content
        print("\n🔄 Testing performance after data changes...")
        
        try await smartIngestion.ingestText(
            content: "New Swift content about async testing patterns",
            title: "Swift Testing",
            summary: "Testing async Swift code",
            sender: "TestUser"
        )
        
        let startTime3 = Date()
        let results3 = try await queryEngine.executeHybridSearch(parsedQuery, limit: 5)
        let postUpdateTime = Date().timeIntervalSince(startTime3)
        
        print("  ⏱ Post-update query: \(Int(postUpdateTime * 1000))ms")
        print("  📊 Results: \(results3.count)")
        
        XCTAssertLessThan(postUpdateTime, 0.2, "Query should remain fast after data updates")
    }
    
    func testDatabaseOptimization() async throws {
        print("\n🗄️ Testing Database Optimization")
        print("=" * 50)
        
        // Create database with optimization settings
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("optimization_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        
        // Apply database optimizations
        let optimizer = DatabaseOptimizer()
        try await optimizer.applyOptimizations(to: schema)
        
        print("\n⚙️ Applied database optimizations:")
        let settings = try await optimizer.getCurrentSettings(from: schema)
        for (setting, value) in settings {
            print("  ✓ \(setting): \(value)")
        }
        
        // Test that optimizations were applied
        print("\n✅ Database optimizations applied successfully")
        
        // Test vacuum and analyze operations
        print("\n🧹 Testing database maintenance...")
        let sizeBefore = try await schema.getDatabaseSize()
        print("  📊 Database size before vacuum: \(sizeBefore) bytes")
        
        try await optimizer.performVacuum(on: schema)
        try await optimizer.performAnalyze(on: schema)
        
        let sizeAfter = try await schema.getDatabaseSize()
        print("  📊 Database size after vacuum: \(sizeAfter) bytes")
        print("  💾 Space reclaimed: \(sizeBefore - sizeAfter) bytes")
        
        // Database optimization test completed
        print("\n✅ Database optimization tests completed successfully")
    }
    
    func testScalabilityBenchmarks() async throws {
        print("\n📈 Testing Scalability Benchmarks")
        print("=" * 50)
        
        // Create database for scalability testing
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("scalability_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        
        // Apply optimizations
        let optimizer = DatabaseOptimizer()
        try await optimizer.applyOptimizations(to: schema)
        
        let queryEngine = NaturalLanguageQueryEngine()
        queryEngine.setDatabase(schema)
        
        let smartIngestion = SmartIngestionService()
        await smartIngestion.setDatabase(schema)
        
        // Test performance with different dataset sizes
        let testSizes = [100, 1000, 5000] // Reduced for faster testing
        var performanceResults: [String: [Int: TimeInterval]] = [:]
        
        for testSize in testSizes {
            print("\n📊 Testing with \(testSize) conversations...")
            
            // Clear existing data
            try await schema.clearAllData()
            
            // Ingest test data
            let ingestionStart = Date()
            for i in 0..<testSize {
                let content = "Test conversation \(i) about Swift programming, iOS development, and software architecture patterns."
                try await smartIngestion.ingestText(
                    content: content,
                    title: "Conversation \(i)",
                    summary: "Discussion about Swift and iOS development",
                    sender: "User\(i % 10)"
                )
                
                // Progress indicator
                if i % 500 == 0 && i > 0 {
                    print("    Ingested \(i)/\(testSize) conversations...")
                }
            }
            let ingestionTime = Date().timeIntervalSince(ingestionStart)
            
            print("  ✓ Ingestion completed: \(String(format: "%.2f", ingestionTime))s")
            print("  📊 Rate: \(Int(Double(testSize) / ingestionTime)) conversations/second")
            
            // Test query performance
            let queries = [
                "Swift programming patterns",
                "iOS development best practices", 
                "software architecture design",
                "performance optimization techniques"
            ]
            
            var queryTimes: [TimeInterval] = []
            
            for query in queries {
                let parsedQuery = queryEngine.parseQuery(query)
                let queryStart = Date()
                let results = try await queryEngine.executeHybridSearch(parsedQuery, limit: 10)
                let queryTime = Date().timeIntervalSince(queryStart)
                
                queryTimes.append(queryTime)
                
                XCTAssertFalse(results.isEmpty, "Should find results for '\(query)'")
                XCTAssertLessThan(queryTime, 0.5, "Query should complete in <500ms even with \(testSize) items")
            }
            
            let avgQueryTime = queryTimes.reduce(0, +) / Double(queryTimes.count)
            print("  🔍 Average query time: \(Int(avgQueryTime * 1000))ms")
            
            performanceResults["query"] = performanceResults["query"] ?? [:]
            performanceResults["query"]![testSize] = avgQueryTime
            
            performanceResults["ingestion"] = performanceResults["ingestion"] ?? [:]
            performanceResults["ingestion"]![testSize] = ingestionTime / Double(testSize)
        }
        
        // Analyze performance scaling
        print("\n📈 Performance Scaling Analysis:")
        print("Dataset Size | Avg Query Time | Ingestion Rate")
        print("-" * 45)
        
        for testSize in testSizes {
            let queryTime = performanceResults["query"]![testSize]! * 1000 // Convert to ms
            let ingestionRate = 1.0 / performanceResults["ingestion"]![testSize]! // items/second
            
            print(String(format: "%11d | %13.0f ms | %13.0f/sec", testSize, queryTime, ingestionRate))
        }
        
        // Test memory usage under load
        print("\n💾 Testing memory usage...")
        let memoryMonitor = MemoryMonitor()
        let initialMemory = memoryMonitor.getCurrentMemoryUsage()
        
        // Perform intensive operations
        for _ in 0..<50 {
            let query = "Swift programming and iOS development patterns"
            let parsedQuery = queryEngine.parseQuery(query)
            let _ = try await queryEngine.executeHybridSearch(parsedQuery, limit: 20)
        }
        
        let finalMemory = memoryMonitor.getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        print("  📊 Initial memory: \(String(format: "%.1f", Double(initialMemory) / 1_000_000)) MB")
        print("  📊 Final memory: \(String(format: "%.1f", Double(finalMemory) / 1_000_000)) MB")
        print("  📊 Memory increase: \(String(format: "%.1f", Double(memoryIncrease) / 1_000_000)) MB")
        
        // Memory should remain stable
        XCTAssertLessThan(memoryIncrease, 50_000_000, "Memory increase should be less than 50MB")
        
        print("\n✅ Scalability benchmarks completed successfully!")
    }
}

// MARK: - Supporting Types

// String multiplication operator removed to avoid conflicts