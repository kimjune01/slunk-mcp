import Foundation

struct TextSummary: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let content: String
    let summary: String
    let category: String?
    let tags: [String]?
    let sourceURL: String?
    let wordCount: Int
    let summaryWordCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    init(title: String, content: String, summary: String, category: String? = nil, tags: [String]? = nil, sourceURL: String? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.summary = summary
        self.category = category
        self.tags = tags
        self.sourceURL = sourceURL
        self.wordCount = Self.countWords(in: content)
        self.summaryWordCount = Self.countWords(in: summary)
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
    
    // MARK: - Validation
    
    static func validate(title: String, content: String, summary: String, category: String? = nil, tags: [String]? = nil, sourceURL: String? = nil) throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TextSummaryError.emptyTitle
        }
        
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TextSummaryError.emptyContent
        }
        
        if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TextSummaryError.emptySummary
        }
    }
    
    // MARK: - Private Helpers
    
    private static func countWords(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
}

// MARK: - Error Types

enum TextSummaryError: Error, Equatable {
    case emptyTitle
    case emptyContent
    case emptySummary
    case invalidData(String)
}

extension TextSummaryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Title cannot be empty"
        case .emptyContent:
            return "Content cannot be empty"
        case .emptySummary:
            return "Summary cannot be empty"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}