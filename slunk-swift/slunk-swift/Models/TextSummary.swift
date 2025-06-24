import Foundation

struct TextSummary: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let content: String
    let summary: String
    
    // Enhanced metadata
    let sender: String?
    let timestamp: Date
    let source: String?
    let keywords: [String]
    let category: String?
    let tags: [String]?
    let sourceURL: String?
    
    // Computed fields
    let wordCount: Int
    let summaryWordCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    // Primary initializer with all fields
    init(title: String, content: String, summary: String, sender: String? = nil, timestamp: Date? = nil, source: String? = nil, keywords: [String] = [], category: String? = nil, tags: [String]? = nil, sourceURL: String? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.summary = summary
        
        // Enhanced metadata with validation
        self.sender = Self.normalizeSender(sender)
        self.timestamp = timestamp ?? Date()
        self.source = source
        self.keywords = Self.normalizeKeywords(keywords)
        self.category = category
        self.tags = tags
        self.sourceURL = sourceURL
        
        // Computed fields
        self.wordCount = Self.countWords(in: content)
        self.summaryWordCount = Self.countWords(in: summary)
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
    
    // Legacy initializer for backward compatibility
    init(title: String, content: String, summary: String, category: String? = nil, tags: [String]? = nil, sourceURL: String? = nil) {
        self.init(
            title: title,
            content: content,
            summary: summary,
            sender: nil,
            timestamp: Date(),
            source: nil,
            keywords: [],
            category: category,
            tags: tags,
            sourceURL: sourceURL
        )
    }
    
    // MARK: - Temporal Query Helpers
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: timestamp)
    }
    
    var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: timestamp)
    }
    
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
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
    
    private static func normalizeSender(_ sender: String?) -> String? {
        guard let sender = sender else { return nil }
        let trimmed = sender.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private static func normalizeKeywords(_ keywords: [String]) -> [String] {
        let validKeywords = keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        
        // Remove duplicates while preserving order
        var seen = Set<String>()
        return validKeywords.filter { seen.insert($0).inserted }
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