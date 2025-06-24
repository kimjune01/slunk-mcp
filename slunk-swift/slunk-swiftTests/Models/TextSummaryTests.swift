import XCTest
@testable import slunk_swift

final class TextSummaryTests: XCTestCase {
    
    func testTextSummaryCreation() {
        // Should create TextSummary with required fields
        let summary = TextSummary(
            title: "Test Title",
            content: "Test content for summary",
            summary: "This is a test summary"
        )
        
        XCTAssertNotNil(summary.id)
        XCTAssertEqual(summary.title, "Test Title")
        XCTAssertEqual(summary.content, "Test content for summary")
        XCTAssertEqual(summary.summary, "This is a test summary")
        XCTAssertNotNil(summary.createdAt)
        XCTAssertNotNil(summary.updatedAt)
        
        // Should generate valid UUID
        XCTAssertNoThrow(UUID(uuidString: summary.id.uuidString))
        
        // Should set timestamps correctly
        let now = Date()
        XCTAssertLessThanOrEqual(abs(summary.createdAt.timeIntervalSince(now)), 1.0)
        XCTAssertLessThanOrEqual(abs(summary.updatedAt.timeIntervalSince(now)), 1.0)
    }
    
    func testTextSummaryValidation() {
        // Should reject empty title
        XCTAssertThrowsError(try TextSummary.validate(title: "", content: "content", summary: "summary")) { error in
            XCTAssertEqual(error as? TextSummaryError, TextSummaryError.emptyTitle)
        }
        
        // Should reject empty content
        XCTAssertThrowsError(try TextSummary.validate(title: "title", content: "", summary: "summary")) { error in
            XCTAssertEqual(error as? TextSummaryError, TextSummaryError.emptyContent)
        }
        
        // Should reject empty summary
        XCTAssertThrowsError(try TextSummary.validate(title: "title", content: "content", summary: "")) { error in
            XCTAssertEqual(error as? TextSummaryError, TextSummaryError.emptySummary)
        }
        
        // Should accept optional fields as nil
        XCTAssertNoThrow(try TextSummary.validate(
            title: "title",
            content: "content", 
            summary: "summary",
            category: nil,
            tags: nil,
            sourceURL: nil
        ))
    }
    
    func testTextSummaryEncoding() {
        // Should encode/decode to/from JSON correctly
        let original = TextSummary(
            title: "Test Title",
            content: "Test content",
            summary: "Test summary",
            category: "test",
            tags: ["tag1", "tag2"],
            sourceURL: "https://example.com"
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        XCTAssertNoThrow(try {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(TextSummary.self, from: data)
            
            // Should preserve all fields including optional ones
            XCTAssertEqual(decoded.id, original.id)
            XCTAssertEqual(decoded.title, original.title)
            XCTAssertEqual(decoded.content, original.content)
            XCTAssertEqual(decoded.summary, original.summary)
            XCTAssertEqual(decoded.category, original.category)
            XCTAssertEqual(decoded.tags, original.tags)
            XCTAssertEqual(decoded.sourceURL, original.sourceURL)
            XCTAssertEqual(decoded.wordCount, original.wordCount)
            XCTAssertEqual(decoded.summaryWordCount, original.summaryWordCount)
        }())
    }
    
    func testTextSummaryWordCounts() {
        // Should calculate word counts correctly
        let summary = TextSummary(
            title: "Test",
            content: "This is a test content with eight words",
            summary: "Test summary here"
        )
        
        XCTAssertEqual(summary.wordCount, 8)
        XCTAssertEqual(summary.summaryWordCount, 3)
    }
    
    func testTextSummaryOptionalFields() {
        // Should handle optional fields correctly
        let summaryWithOptionals = TextSummary(
            title: "Test",
            content: "Content",
            summary: "Summary",
            category: "test-category",
            tags: ["ai", "test"],
            sourceURL: "https://example.com"
        )
        
        XCTAssertEqual(summaryWithOptionals.category, "test-category")
        XCTAssertEqual(summaryWithOptionals.tags?.count, 2)
        XCTAssertEqual(summaryWithOptionals.sourceURL, "https://example.com")
        
        // Should handle nil optional fields
        let summaryWithoutOptionals = TextSummary(
            title: "Test",
            content: "Content", 
            summary: "Summary"
        )
        
        XCTAssertNil(summaryWithoutOptionals.category)
        XCTAssertNil(summaryWithoutOptionals.tags)
        XCTAssertNil(summaryWithoutOptionals.sourceURL)
    }
}