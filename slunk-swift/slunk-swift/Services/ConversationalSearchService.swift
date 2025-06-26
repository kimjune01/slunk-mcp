import Foundation

/// Service for managing multi-turn search sessions with context awareness and refinement
actor ConversationalSearchService {
    private let queryEngine: NaturalLanguageQueryEngine
    private let embeddingService: EmbeddingService
    private var activeSessions: [String: SearchSession] = [:]
    private let maxSessionHistory = 10
    
    init(queryEngine: NaturalLanguageQueryEngine, embeddingService: EmbeddingService) {
        self.queryEngine = queryEngine
        self.embeddingService = embeddingService
    }
    
    // MARK: - Session Management
    
    func startSession(sessionId: String? = nil) -> String {
        let id = sessionId ?? UUID().uuidString
        activeSessions[id] = SearchSession(id: id)
        return id
    }
    
    func endSession(_ sessionId: String) {
        activeSessions.removeValue(forKey: sessionId)
    }
    
    func getActiveSessionCount() -> Int {
        return activeSessions.count
    }
    
    // MARK: - Conversational Search
    
    func search(
        query: String,
        sessionId: String,
        context: SearchContext? = nil,
        limit: Int = 10
    ) async throws -> ConversationalSearchResult {
        
        guard let session = activeSessions[sessionId] else {
            throw ConversationalSearchError.sessionNotFound(sessionId)
        }
        
        // Parse the current query
        let parsedQuery = queryEngine.parseQuery(query)
        
        // Enhance query with session context
        let enhancedQuery = await enhanceQueryWithContext(
            parsedQuery: parsedQuery,
            session: session,
            additionalContext: context
        )
        
        // Execute search
        let searchResults = try await queryEngine.executeHybridSearch(enhancedQuery, limit: limit)
        
        // Create search turn
        let searchTurn = SearchTurn(
            query: query,
            parsedQuery: parsedQuery,
            enhancedQuery: enhancedQuery,
            results: searchResults,
            timestamp: Date()
        )
        
        // Update session with new turn
        await updateSession(session, with: searchTurn)
        
        // Generate refinement suggestions
        let refinementSuggestions = generateRefinementSuggestions(
            currentQuery: parsedQuery,
            sessionHistory: session.searchHistory,
            results: searchResults
        )
        
        return ConversationalSearchResult(
            sessionId: sessionId,
            turnNumber: session.searchHistory.count,
            originalQuery: query,
            enhancedQuery: enhancedQuery,
            results: searchResults,
            refinementSuggestions: refinementSuggestions,
            sessionContext: extractSessionContext(from: session)
        )
    }
    
    func refineLastSearch(
        sessionId: String,
        refinement: SearchRefinement,
        limit: Int = 10
    ) async throws -> ConversationalSearchResult {
        
        guard let session = activeSessions[sessionId],
              let lastTurn = session.searchHistory.last else {
            throw ConversationalSearchError.sessionNotFound(sessionId)
        }
        
        // Apply refinement to last query
        let refinedQuery = applyRefinement(to: lastTurn.enhancedQuery, refinement: refinement)
        
        // Execute refined search
        let searchResults = try await queryEngine.executeHybridSearch(refinedQuery, limit: limit)
        
        // Create refinement turn
        let refinementTurn = SearchTurn(
            query: lastTurn.query + " [refined: \(refinement.description)]",
            parsedQuery: refinedQuery,
            enhancedQuery: refinedQuery,
            results: searchResults,
            timestamp: Date(),
            isRefinement: true,
            refinementType: refinement
        )
        
        // Update session
        await updateSession(session, with: refinementTurn)
        
        return ConversationalSearchResult(
            sessionId: sessionId,
            turnNumber: session.searchHistory.count,
            originalQuery: refinementTurn.query,
            enhancedQuery: refinedQuery,
            results: searchResults,
            refinementSuggestions: [],
            sessionContext: extractSessionContext(from: session)
        )
    }
    
    // MARK: - Private Implementation
    
    private func enhanceQueryWithContext(
        parsedQuery: ParsedQuery,
        session: SearchSession,
        additionalContext: SearchContext?
    ) async -> ParsedQuery {
        
        var enhancedKeywords = parsedQuery.keywords
        var enhancedChannels = parsedQuery.channels
        var enhancedUsers = parsedQuery.users
        var enhancedEntities = parsedQuery.entities
        
        // Add context from previous searches in session
        if let previousContext = extractImplicitContext(from: session.searchHistory) {
            enhancedKeywords.append(contentsOf: previousContext.impliedKeywords)
            enhancedChannels.append(contentsOf: previousContext.impliedChannels)
            enhancedUsers.append(contentsOf: previousContext.impliedUsers)
        }
        
        // Add explicit additional context
        if let context = additionalContext {
            enhancedKeywords.append(contentsOf: context.additionalKeywords)
            enhancedChannels.append(contentsOf: context.focusChannels)
            enhancedUsers.append(contentsOf: context.focusUsers)
        }
        
        // Remove duplicates while preserving order
        enhancedKeywords = Array(NSOrderedSet(array: enhancedKeywords)) as! [String]
        enhancedChannels = Array(NSOrderedSet(array: enhancedChannels)) as! [String]
        enhancedUsers = Array(NSOrderedSet(array: enhancedUsers)) as! [String]
        enhancedEntities = Array(NSOrderedSet(array: enhancedEntities)) as! [String]
        
        return ParsedQuery(
            originalText: parsedQuery.originalText,
            intent: parsedQuery.intent,
            keywords: enhancedKeywords,
            entities: enhancedEntities,
            channels: enhancedChannels,
            users: enhancedUsers,
            temporalHint: parsedQuery.temporalHint
        )
    }
    
    private func updateSession(_ session: SearchSession, with turn: SearchTurn) async {
        session.searchHistory.append(turn)
        
        // Maintain session history size limit
        if session.searchHistory.count > maxSessionHistory {
            session.searchHistory.removeFirst()
        }
        
        session.lastActivity = Date()
    }
    
    private func extractImplicitContext(from searchHistory: [SearchTurn]) -> ImplicitContext? {
        guard searchHistory.count >= 2 else { return nil }
        
        // Extract common themes from recent searches
        let recentTurns = Array(searchHistory.suffix(3))
        
        let allKeywords = recentTurns.flatMap { $0.parsedQuery.keywords }
        let allChannels = recentTurns.flatMap { $0.parsedQuery.channels }
        let allUsers = recentTurns.flatMap { $0.parsedQuery.users }
        
        // Find frequently mentioned items
        let keywordCounts = Dictionary(grouping: allKeywords, by: { $0 }).mapValues { $0.count }
        let channelCounts = Dictionary(grouping: allChannels, by: { $0 }).mapValues { $0.count }
        let userCounts = Dictionary(grouping: allUsers, by: { $0 }).mapValues { $0.count }
        
        // Include items mentioned in multiple turns
        let impliedKeywords = keywordCounts.filter { $0.value > 1 }.map { $0.key }
        let impliedChannels = channelCounts.filter { $0.value > 1 }.map { $0.key }
        let impliedUsers = userCounts.filter { $0.value > 1 }.map { $0.key }
        
        return ImplicitContext(
            impliedKeywords: impliedKeywords,
            impliedChannels: impliedChannels,
            impliedUsers: impliedUsers
        )
    }
    
    private func generateRefinementSuggestions(
        currentQuery: ParsedQuery,
        sessionHistory: [SearchTurn],
        results: [QueryResult]
    ) -> [RefinementSuggestion] {
        
        var suggestions: [RefinementSuggestion] = []
        
        // Temporal refinements
        if currentQuery.temporalHint == nil {
            suggestions.append(RefinementSuggestion(
                type: .addTimeFilter,
                description: "Add time filter (e.g., 'last week', 'yesterday')",
                suggestedModification: "Add temporal context to narrow results"
            ))
        }
        
        // Channel/user refinements
        if currentQuery.channels.isEmpty && !results.isEmpty {
            suggestions.append(RefinementSuggestion(
                type: .addChannelFilter,
                description: "Filter by specific channels",
                suggestedModification: "Add channel context to focus results"
            ))
        }
        
        if currentQuery.users.isEmpty && !results.isEmpty {
            suggestions.append(RefinementSuggestion(
                type: .addUserFilter,
                description: "Filter by specific users",
                suggestedModification: "Add user context to focus results"
            ))
        }
        
        // Result-based refinements
        if results.count >= 8 {
            suggestions.append(RefinementSuggestion(
                type: .narrowScope,
                description: "Narrow search scope with more specific terms",
                suggestedModification: "Add more specific keywords"
            ))
        }
        
        if results.count <= 2 {
            suggestions.append(RefinementSuggestion(
                type: .expandScope,
                description: "Expand search with broader terms",
                suggestedModification: "Use broader or alternative keywords"
            ))
        }
        
        // Session-based refinements
        if sessionHistory.count > 1 {
            suggestions.append(RefinementSuggestion(
                type: .combineWithPrevious,
                description: "Combine with previous search context",
                suggestedModification: "Merge themes from recent searches"
            ))
        }
        
        return Array(suggestions.prefix(3)) // Limit to 3 suggestions
    }
    
    private func applyRefinement(to query: ParsedQuery, refinement: SearchRefinement) -> ParsedQuery {
        var modifiedKeywords = query.keywords
        var modifiedChannels = query.channels
        var modifiedUsers = query.users
        
        switch refinement.type {
        case .addKeywords:
            modifiedKeywords.append(contentsOf: refinement.keywords)
        case .removeKeywords:
            modifiedKeywords = modifiedKeywords.filter { !refinement.keywords.contains($0) }
        case .addChannelFilter:
            modifiedChannels.append(contentsOf: refinement.channels)
        case .addUserFilter:
            modifiedUsers.append(contentsOf: refinement.users)
        case .changeTimeRange:
            // Would modify temporal hint - simplified for now
            break
        }
        
        return ParsedQuery(
            originalText: query.originalText + " [refined]",
            intent: query.intent,
            keywords: Array(Set(modifiedKeywords)),
            entities: query.entities,
            channels: Array(Set(modifiedChannels)),
            users: Array(Set(modifiedUsers)),
            temporalHint: refinement.temporalHint ?? query.temporalHint
        )
    }
    
    private func extractSessionContext(from session: SearchSession) -> SessionContext {
        let recentQueries = session.searchHistory.suffix(3).map { $0.query }
        let dominantTopics = extractDominantTopics(from: session.searchHistory)
        let searchPatterns = analyzeSearchPatterns(from: session.searchHistory)
        
        return SessionContext(
            sessionId: session.id,
            turnCount: session.searchHistory.count,
            recentQueries: Array(recentQueries),
            dominantTopics: dominantTopics,
            searchPatterns: searchPatterns,
            sessionDuration: Date().timeIntervalSince(session.startTime)
        )
    }
    
    private func extractDominantTopics(from searchHistory: [SearchTurn]) -> [String] {
        let allKeywords = searchHistory.flatMap { $0.parsedQuery.keywords }
        let keywordCounts = Dictionary(grouping: allKeywords, by: { $0 }).mapValues { $0.count }
        
        return keywordCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    private func analyzeSearchPatterns(from searchHistory: [SearchTurn]) -> [String] {
        var patterns: [String] = []
        
        let refinementCount = searchHistory.filter { $0.isRefinement }.count
        if refinementCount > 0 {
            patterns.append("Uses search refinements")
        }
        
        let intentVariety = Set(searchHistory.map { $0.parsedQuery.intent }).count
        if intentVariety > 2 {
            patterns.append("Diverse search intents")
        }
        
        let channelFocused = searchHistory.contains { !$0.parsedQuery.channels.isEmpty }
        if channelFocused {
            patterns.append("Channel-focused searches")
        }
        
        return patterns
    }
}

// MARK: - Supporting Types

class SearchSession {
    let id: String
    let startTime: Date
    var lastActivity: Date
    var searchHistory: [SearchTurn]
    
    init(id: String) {
        self.id = id
        self.startTime = Date()
        self.lastActivity = Date()
        self.searchHistory = []
    }
}

struct SearchTurn {
    let query: String
    let parsedQuery: ParsedQuery
    let enhancedQuery: ParsedQuery
    let results: [QueryResult]
    let timestamp: Date
    let isRefinement: Bool
    let refinementType: SearchRefinement?
    
    init(
        query: String,
        parsedQuery: ParsedQuery,
        enhancedQuery: ParsedQuery,
        results: [QueryResult],
        timestamp: Date,
        isRefinement: Bool = false,
        refinementType: SearchRefinement? = nil
    ) {
        self.query = query
        self.parsedQuery = parsedQuery
        self.enhancedQuery = enhancedQuery
        self.results = results
        self.timestamp = timestamp
        self.isRefinement = isRefinement
        self.refinementType = refinementType
    }
}

struct ConversationalSearchResult {
    let sessionId: String
    let turnNumber: Int
    let originalQuery: String
    let enhancedQuery: ParsedQuery
    let results: [QueryResult]
    let refinementSuggestions: [RefinementSuggestion]
    let sessionContext: SessionContext
}

struct SearchContext {
    let additionalKeywords: [String]
    let focusChannels: [String]
    let focusUsers: [String]
    let temporalFocus: TemporalHint?
    
    init(
        additionalKeywords: [String] = [],
        focusChannels: [String] = [],
        focusUsers: [String] = [],
        temporalFocus: TemporalHint? = nil
    ) {
        self.additionalKeywords = additionalKeywords
        self.focusChannels = focusChannels
        self.focusUsers = focusUsers
        self.temporalFocus = temporalFocus
    }
}

struct SearchRefinement {
    let type: RefinementType
    let keywords: [String]
    let channels: [String]
    let users: [String]
    let temporalHint: TemporalHint?
    
    var description: String {
        switch type {
        case .addKeywords:
            return "add keywords: \(keywords.joined(separator: ", "))"
        case .removeKeywords:
            return "remove keywords: \(keywords.joined(separator: ", "))"
        case .addChannelFilter:
            return "filter channels: \(channels.joined(separator: ", "))"
        case .addUserFilter:
            return "filter users: \(users.joined(separator: ", "))"
        case .changeTimeRange:
            return "change time range"
        }
    }
    
    enum RefinementType {
        case addKeywords
        case removeKeywords
        case addChannelFilter
        case addUserFilter
        case changeTimeRange
    }
}

struct RefinementSuggestion {
    let type: SuggestionType
    let description: String
    let suggestedModification: String
    
    enum SuggestionType {
        case addTimeFilter
        case addChannelFilter
        case addUserFilter
        case narrowScope
        case expandScope
        case combineWithPrevious
    }
}

struct SessionContext {
    let sessionId: String
    let turnCount: Int
    let recentQueries: [String]
    let dominantTopics: [String]
    let searchPatterns: [String]
    let sessionDuration: TimeInterval
}

private struct ImplicitContext {
    let impliedKeywords: [String]
    let impliedChannels: [String]
    let impliedUsers: [String]
}

enum ConversationalSearchError: Error, LocalizedError {
    case sessionNotFound(String)
    case invalidRefinement(String)
    case searchEngineUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .sessionNotFound(let sessionId):
            return "Search session not found: \(sessionId)"
        case .invalidRefinement(let reason):
            return "Invalid search refinement: \(reason)"
        case .searchEngineUnavailable:
            return "Search engine is not available"
        }
    }
}