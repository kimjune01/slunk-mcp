import XCTest
import Foundation
@testable import slunk_swift

final class SimpleQueryParsingTest: XCTestCase {
    
    func testBasicTextProcessing() {
        // Test basic string processing functionality 
        // (placeholder for future query parsing implementation)
        
        let query = "Find Swift documents"
        let keywords = query.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        
        print("Original query: \(query)")
        print("Basic keywords: \(keywords)")
        
        // Basic assertions
        XCTAssertFalse(keywords.isEmpty, "Should extract some keywords")
        XCTAssertTrue(keywords.contains("swift"), "Should contain 'swift'")
        XCTAssertTrue(keywords.contains("documents"), "Should contain 'documents'")
        
        print("✅ Basic text processing working")
    }
    
    func testChannelExtraction() {
        // Test extraction of channel mentions from queries
        let queryWithChannel = "Search in #engineering for API docs"
        let channelPattern = try! NSRegularExpression(pattern: "#([a-zA-Z0-9_-]+)")
        let matches = channelPattern.matches(
            in: queryWithChannel,
            range: NSRange(location: 0, length: queryWithChannel.utf16.count)
        )
        
        let channels: [String] = matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: queryWithChannel) else { return nil }
            return String(queryWithChannel[range])
        }
        
        XCTAssertEqual(channels, ["engineering"], "Should extract channel name")
        print("✅ Channel extraction working: found \(channels)")
    }
    
    func testUserMentionExtraction() {
        // Test extraction of user mentions from queries
        let queryWithUser = "Messages from @alice about the project"
        let userPattern = try! NSRegularExpression(pattern: "@([a-zA-Z0-9_-]+)")
        let matches = userPattern.matches(
            in: queryWithUser,
            range: NSRange(location: 0, length: queryWithUser.utf16.count)
        )
        
        let users: [String] = matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: queryWithUser) else { return nil }
            return String(queryWithUser[range])
        }
        
        XCTAssertEqual(users, ["alice"], "Should extract user name")
        print("✅ User mention extraction working: found \(users)")
    }
}