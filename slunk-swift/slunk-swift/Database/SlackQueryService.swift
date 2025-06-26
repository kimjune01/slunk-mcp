import Foundation

// Simplified SlackQueryService for Phase 1 verification
// Contains core types and basic query structure without GRDB complexity

public actor SlackQueryService {
    private let messageContextualizer: MessageContextualizer
    
    public init(messageContextualizer: MessageContextualizer) {
        self.messageContextualizer = messageContextualizer
    }
    
    // MARK: - Basic Query Filters
    
    public func filterByChannels(_ channels: [String]) -> QueryFilter {
        return QueryFilter(
            type: .channel,
            values: channels,
            sqlFragment: "channel IN (\(channels.map { "'\($0)'" }.joined(separator: ",")))"
        )
    }
    
    public func filterByUsers(_ users: [String]) -> QueryFilter {
        return QueryFilter(
            type: .user,
            values: users,
            sqlFragment: "sender IN (\(users.map { "'\($0)'" }.joined(separator: ",")))"
        )
    }
    
    public func filterByTimeRange(from startDate: Date, to endDate: Date) -> QueryFilter {
        return QueryFilter(
            type: .timeRange,
            values: [startDate.timeIntervalSince1970.description, endDate.timeIntervalSince1970.description],
            sqlFragment: "timestamp BETWEEN \(startDate.timeIntervalSince1970) AND \(endDate.timeIntervalSince1970)"
        )
    }
    
    // MARK: - Conversation Chunk Methods
    
    public func createConversationChunks(
        for messages: [SlackMessage],
        timeWindow: TimeInterval = 600 // 10 minutes
    ) async -> [ConversationChunk] {
        return await messageContextualizer.createConversationChunks(
            from: messages, 
            timeWindow: timeWindow
        )
    }
}

// MARK: - Supporting Types

public struct QueryFilter {
    public let type: FilterType
    public let values: [String]
    public let sqlFragment: String
    
    public enum FilterType {
        case channel, user, messageType, timeRange, reactions, attachments
    }
    
    public init(type: FilterType, values: [String], sqlFragment: String) {
        self.type = type
        self.values = values
        self.sqlFragment = sqlFragment
    }
}

public struct SemanticQuery {
    public let embedding: [Float]
    public let minSimilarity: Float
    public let originalQuery: String?
    
    public init(embedding: [Float], minSimilarity: Float = 0.7, originalQuery: String? = nil) {
        self.embedding = embedding
        self.minSimilarity = minSimilarity
        self.originalQuery = originalQuery
    }
}

public enum SearchMode {
    case semantic, structured, hybrid
}

public struct SlackSearchResult {
    public let message: SlackMessage
    public let similarity: Float?
    public let contextualMeaning: String?
    public let threadContext: ThreadContext?
    public let resultType: ResultType
    
    public enum ResultType {
        case message, contextualMessage, structured, chunk
    }
    
    public init(
        message: SlackMessage,
        similarity: Float? = nil,
        contextualMeaning: String? = nil,
        threadContext: ThreadContext? = nil,
        resultType: ResultType
    ) {
        self.message = message
        self.similarity = similarity
        self.contextualMeaning = contextualMeaning
        self.threadContext = threadContext
        self.resultType = resultType
    }
}

public struct SearchMetadata {
    public let totalResults: Int
    public let contextualMatches: Int
    public let chunkMatches: Int
    public let searchType: SearchMode
    public let contextEnhancement: Bool
    
    public init(totalResults: Int, contextualMatches: Int, chunkMatches: Int, searchType: SearchMode, contextEnhancement: Bool) {
        self.totalResults = totalResults
        self.contextualMatches = contextualMatches
        self.chunkMatches = chunkMatches
        self.searchType = searchType
        self.contextEnhancement = contextEnhancement
    }
}

public enum SlackQueryError: Error {
    case missingSemanticQuery
    case invalidTimeRange
    case databaseError(String)
}