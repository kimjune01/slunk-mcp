import XCTest
import Foundation
@testable import slunk_swift

final class SimpleQueryParsingTest: XCTestCase {
    
    func testBasicQueryParsing() {
        let engine = NaturalLanguageQueryEngine()
        
        // Test a simple query
        let query = "Find Swift documents"
        let parsed = engine.parseQuery(query)
        
        print("Original query: \(query)")
        print("Parsed intent: \(parsed.intent)")
        print("Parsed keywords: \(parsed.keywords)")
        print("Parsed entities: \(parsed.entities)")
        print("Parsed temporal hint: \(parsed.temporalHint?.value ?? "none")")
        
        // Basic assertions
        XCTAssertEqual(parsed.originalText, query.lowercased())
        XCTAssertFalse(parsed.keywords.isEmpty, "Should extract some keywords")
        
        // Should extract "swift" and "documents" as keywords
        let hasSwift = parsed.keywords.contains("swift")
        let hasDocuments = parsed.keywords.contains("documents")
        
        print("Contains 'swift': \(hasSwift)")
        print("Contains 'documents': \(hasDocuments)")
        
        XCTAssertTrue(hasSwift || hasDocuments, "Should extract at least one relevant keyword")
    }
    
    func testIntentDetection() {
        let engine = NaturalLanguageQueryEngine()
        
        let testCases = [
            ("find documents", QueryIntent.search),
            ("show me files", QueryIntent.show),
            ("search for Swift", QueryIntent.search)
        ]
        
        for (query, expectedIntent) in testCases {
            let parsed = engine.parseQuery(query)
            print("Query: '\(query)' -> Intent: \(parsed.intent)")
            XCTAssertEqual(parsed.intent, expectedIntent, "Should detect correct intent for '\(query)'")
        }
    }
    
    func testKeywordExtraction() {
        let engine = NaturalLanguageQueryEngine()
        
        let query = "Show me Swift programming tutorials"
        let parsed = engine.parseQuery(query)
        
        print("Keywords extracted: \(parsed.keywords)")
        
        // Should extract meaningful words, not stop words
        XCTAssertFalse(parsed.keywords.contains("me"), "Should not include stop words")
        XCTAssertFalse(parsed.keywords.contains("show"), "Should not include intent words")
        
        // Should include meaningful keywords
        let meaningfulKeywords = ["swift", "programming", "tutorials"]
        let extractedMeaningful = meaningfulKeywords.filter { parsed.keywords.contains($0) }
        
        XCTAssertFalse(extractedMeaningful.isEmpty, "Should extract at least one meaningful keyword")
    }
}