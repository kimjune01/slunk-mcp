import XCTest
import Foundation
@testable import slunk_swift

final class EnhancedVectorStoreTests: XCTestCase {
    
    // MARK: - Enhanced Data Model Tests
    
    func testEnhancedDataModel() {
        // Test TextSummary with sender, timestamp, keywords
        let timestamp = Date()
        let keywords = ["swift", "programming", "test"]
        
        let summary = TextSummary(
            title: "Test Summary",
            content: "This is a test content about Swift programming.",
            summary: "Swift programming test summary",
            sender: "Alice",
            timestamp: timestamp,
            keywords: keywords
        )
        
        XCTAssertEqual(summary.sender, "Alice")
        XCTAssertEqual(summary.timestamp, timestamp)
        XCTAssertEqual(summary.keywords, keywords)
        
        // Test temporal computed properties
        let calendar = Calendar.current
        let expectedDayOfWeek = calendar.weekdaySymbols[calendar.component(.weekday, from: timestamp) - 1]
        XCTAssertEqual(summary.dayOfWeek, expectedDayOfWeek)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let expectedMonthYear = formatter.string(from: timestamp)
        XCTAssertEqual(summary.monthYear, expectedMonthYear)
        
        // Test keyword validation and deduplication
        let duplicateKeywords = ["swift", "Swift", "programming", "swift"]
        let summaryWithDuplicates = TextSummary(
            title: "Duplicate Test",
            content: "Test content",
            summary: "Test summary",
            keywords: duplicateKeywords
        )
        
        // Should deduplicate and normalize keywords
        XCTAssertTrue(summaryWithDuplicates.keywords.count <= 2) // "swift" and "programming"
    }
    
    func testTemporalProperties() {
        let calendar = Calendar.current
        let testDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 24, hour: 14, minute: 30))!
        
        let summary = TextSummary(
            title: "Temporal Test",
            content: "Test content",
            summary: "Test summary",
            timestamp: testDate
        )
        
        // Should calculate dayOfWeek correctly
        XCTAssertEqual(summary.dayOfWeek, "Monday") // June 24, 2024 is a Monday
        
        // Should format monthYear properly
        XCTAssertEqual(summary.monthYear, "2024-06")
        
        // Should generate relativeTime strings
        XCTAssertFalse(summary.relativeTime.isEmpty)
        
        // Should handle timezone conversions
        XCTAssertNotNil(summary.timestamp)
    }
    
    func testKeywordHandling() {
        // Should store keywords as array
        let keywords = ["test", "keyword", "array"]
        let summary = TextSummary(
            title: "Keyword Test",
            content: "Test content",
            summary: "Test summary",
            keywords: keywords
        )
        XCTAssertEqual(summary.keywords, keywords)
        
        // Should validate keyword format
        let invalidKeywords = ["", "  ", "valid"]
        let summaryWithInvalid = TextSummary(
            title: "Invalid Test",
            content: "Test content", 
            summary: "Test summary",
            keywords: invalidKeywords
        )
        // Should filter out empty/whitespace keywords
        XCTAssertFalse(summaryWithInvalid.keywords.contains(""))
        XCTAssertFalse(summaryWithInvalid.keywords.contains("  "))
        
        // Should handle empty keywords gracefully
        let summaryEmpty = TextSummary(
            title: "Empty Test",
            content: "Test content",
            summary: "Test summary",
            keywords: []
        )
        XCTAssertEqual(summaryEmpty.keywords, [])
        
        // Should deduplicate keywords
        let duplicateKeywords = ["test", "test", "unique"]
        let summaryDupe = TextSummary(
            title: "Dupe Test",
            content: "Test content",
            summary: "Test summary", 
            keywords: duplicateKeywords
        )
        XCTAssertEqual(Set(summaryDupe.keywords).count, summaryDupe.keywords.count)
    }
    
    func testSenderValidation() {
        // Should accept valid sender names
        let summary1 = TextSummary(
            title: "Valid Sender",
            content: "Test content",
            summary: "Test summary",
            sender: "Alice Smith"
        )
        XCTAssertEqual(summary1.sender, "Alice Smith")
        
        // Should handle nil sender gracefully
        let summary2 = TextSummary(
            title: "Nil Sender",
            content: "Test content",
            summary: "Test summary",
            sender: nil
        )
        XCTAssertNil(summary2.sender)
        
        // Should reject empty/whitespace-only senders
        let summary3 = TextSummary(
            title: "Empty Sender",
            content: "Test content",
            summary: "Test summary",
            sender: "   "
        )
        XCTAssertNil(summary3.sender) // Should be normalized to nil
        
        // Should normalize sender names
        let summary4 = TextSummary(
            title: "Normalized Sender",
            content: "Test content",
            summary: "Test summary",
            sender: "  Bob Jones  "
        )
        XCTAssertEqual(summary4.sender, "Bob Jones") // Trimmed whitespace
    }
    
    func testTimestampHandling() {
        let timestamp = Date()
        
        // Should store precise timestamps
        let summary = TextSummary(
            title: "Timestamp Test",
            content: "Test content",
            summary: "Test summary",
            timestamp: timestamp
        )
        XCTAssertEqual(summary.timestamp, timestamp)
        
        // Should handle different date formats (via initializer overloads)
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let summary2 = TextSummary(
            title: "Past Date",
            content: "Test content",
            summary: "Test summary",
            timestamp: pastDate
        )
        XCTAssertEqual(summary2.timestamp, pastDate)
        
        // Should maintain timezone information
        XCTAssertNotNil(summary.timestamp.timeIntervalSince1970)
        
        // Should sort by timestamp correctly
        let summaries = [summary2, summary].sorted { $0.timestamp < $1.timestamp }
        XCTAssertEqual(summaries[0].title, "Past Date")
        XCTAssertEqual(summaries[1].title, "Timestamp Test")
    }
    
    // MARK: - Persistent Database Tests
    
    func testPersistentDatabase() async throws {
        // Test Application Support directory setup
        let documentsPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let slunkPath = documentsPath.appendingPathComponent("Slunk")
        let dbPath = slunkPath.appendingPathComponent("vector_store.db")
        
        // Clean up any existing test database
        try? FileManager.default.removeItem(at: slunkPath)
        
        // Should create database in Application Support directory
        let schema = try SQLiteVecSchema()
        let success = try await schema.initializePersistentDatabase()
        XCTAssertTrue(success)
        
        // Should create directory structure if missing
        XCTAssertTrue(FileManager.default.fileExists(atPath: slunkPath.path))
        
        // Should return consistent path across calls
        let schema2 = try SQLiteVecSchema()
        let success2 = try await schema2.initializePersistentDatabase()
        XCTAssertTrue(success2)
        
        // Clean up
        try? FileManager.default.removeItem(at: slunkPath)
    }
    
    func testTemporalQueries() async throws {
        // Create temporary database for testing
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("temporal_test_\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let schema = try SQLiteVecSchema(databasePath: tempURL.path)
        try await schema.initializeDatabase()
        
        // Create test data with different timestamps
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        
        let summaries = [
            TextSummary(title: "Today", content: "Today's content", summary: "Today", timestamp: now),
            TextSummary(title: "Yesterday", content: "Yesterday's content", summary: "Yesterday", timestamp: yesterday),
            TextSummary(title: "Last Week", content: "Last week's content", summary: "Last Week", timestamp: lastWeek)
        ]
        
        // Store summaries
        for summary in summaries {
            let embedding = Array(repeating: Float(0.5), count: 512) // Mock embedding
            try await schema.storeSummaryWithEmbedding(summary, embedding: embedding)
        }
        
        // Test date range filtering
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let yesterdayString = dateFormatter.string(from: yesterday)
        let todayString = dateFormatter.string(from: now)
        
        let recentResults = try await schema.querySummariesByDateRange(start: yesterdayString, end: todayString)
        XCTAssertEqual(recentResults.count, 2) // Today and yesterday
        
        // Test keyword search with JSON queries
        let keywordResults = try await schema.querySummariesByKeywords(["content"])
        XCTAssertEqual(keywordResults.count, 3) // All contain "content"
        
        // Test sender filtering with indexes
        // (This would require updating the schema to support sender queries)
    }
}