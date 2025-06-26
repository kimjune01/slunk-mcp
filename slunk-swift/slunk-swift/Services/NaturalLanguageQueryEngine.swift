import Foundation
import NaturalLanguage

/// Natural language query engine that combines parsing, hybrid search, and result ranking
class NaturalLanguageQueryEngine {
    private var database: SQLiteVecSchema?
    private let embeddingService: EmbeddingService
    private let queryParser: QueryParser
    
    init() {
        self.embeddingService = EmbeddingService()
        self.queryParser = QueryParser()
    }
    
    // MARK: - Configuration
    
    func setDatabase(_ database: SQLiteVecSchema) {
        self.database = database
    }
    
    // MARK: - Query Processing
    
    func parseQuery(_ query: String) -> ParsedQuery {
        return queryParser.parse(query)
    }
    
    func executeHybridSearch(_ query: ParsedQuery, limit: Int = 10) async throws -> [QueryResult] {
        guard let database = database else {
            throw QueryEngineError.databaseNotAvailable
        }
        
        // Generate embedding for semantic search
        let queryEmbedding = try await embeddingService.generateEmbedding(for: query.originalText)
        
        // Execute hybrid search with combined SQL query
        let results = try await executeHybridSearchSQL(
            database: database,
            queryEmbedding: queryEmbedding,
            parsedQuery: query,
            limit: limit
        )
        
        return results
    }
    
    // MARK: - Private Implementation
    
    private func executeHybridSearchSQL(
        database: SQLiteVecSchema,
        queryEmbedding: [Float],
        parsedQuery: ParsedQuery,
        limit: Int
    ) async throws -> [QueryResult] {
        
        // Build temporal filter
        var temporalFilter = ""
        var temporalParams: [Any] = []
        
        if let temporalHint = parsedQuery.temporalHint {
            let dateRange = resolveTemporalHint(temporalHint)
            if let startDate = dateRange.start, let endDate = dateRange.end {
                temporalFilter = "AND ts.timestamp BETWEEN ? AND ?"
                temporalParams = [startDate, endDate]
            }
        }
        
        // Build keyword filter
        var keywordFilter = ""
        var keywordParams: [Any] = []
        
        if !parsedQuery.keywords.isEmpty {
            let keywordConditions = parsedQuery.keywords.map { _ in "ts.keywords LIKE ?" }
            keywordFilter = "AND (\(keywordConditions.joined(separator: " OR ")))"
            keywordParams = parsedQuery.keywords.map { "%\"\($0)\"%"}
        }
        
        // Combined hybrid search SQL
        let sql = """
            WITH semantic_results AS (
                SELECT summary_id, distance as semantic_score 
                FROM summary_embeddings 
                WHERE embedding MATCH ? AND k = ?
            ),
            keyword_scores AS (
                SELECT id,
                       CASE 
                           WHEN \(parsedQuery.keywords.isEmpty ? "0" : keywordScoreSQL(for: parsedQuery.keywords)) > 0 THEN 1.0
                           ELSE 0.0
                       END as keyword_score
                FROM text_summaries ts
                WHERE 1=1 \(temporalFilter)
            ),
            combined_results AS (
                SELECT ts.*, 
                       COALESCE(sr.semantic_score, 1.0) as semantic_score,
                       COALESCE(ks.keyword_score, 0.0) as keyword_score,
                       (COALESCE(1.0 - sr.semantic_score, 0.0) * 0.6 + COALESCE(ks.keyword_score, 0.0) * 0.4) as combined_score
                FROM text_summaries ts
                LEFT JOIN semantic_results sr ON ts.id = sr.summary_id
                LEFT JOIN keyword_scores ks ON ts.id = ks.id
                WHERE (sr.summary_id IS NOT NULL OR ks.keyword_score > 0)
                \(temporalFilter.isEmpty ? "" : "AND ts.timestamp BETWEEN ? AND ?")
            )
            SELECT * FROM combined_results 
            ORDER BY combined_score DESC 
            LIMIT ?
        """
        
        // Build parameters
        var params: [Any] = [queryEmbedding, min(limit * 2, 50)] // Get more semantic results for better ranking
        params.append(contentsOf: keywordParams)
        if !temporalFilter.isEmpty {
            params.append(contentsOf: temporalParams)
        }
        params.append(limit)
        
        // Execute query - for now, let's use a simpler approach
        return try await executeSimplifiedHybridSearch(
            database: database,
            queryEmbedding: queryEmbedding,
            parsedQuery: parsedQuery,
            limit: limit
        )
    }
    
    private func executeSimplifiedHybridSearch(
        database: SQLiteVecSchema,
        queryEmbedding: [Float],
        parsedQuery: ParsedQuery,
        limit: Int
    ) async throws -> [QueryResult] {
        
        // First, get semantic similarity results
        let vectorResults = try await database.searchSimilarVectors(queryEmbedding, limit: limit * 2)
        
        // Then get keyword matches if we have keywords
        var keywordMatches: [TextSummary] = []
        if !parsedQuery.keywords.isEmpty {
            keywordMatches = try await database.querySummariesByKeywords(parsedQuery.keywords)
        }
        
        // Apply temporal filtering if needed
        var filteredResults: [QueryResult] = []
        
        for vectorResult in vectorResults {
            // Try to find the corresponding TextSummary
            // This is a simplified approach - in production we'd join these properly
            let semanticScore = 1.0 - vectorResult.distance // Convert distance to similarity
            let keywordScore = keywordMatches.contains { $0.id.uuidString == vectorResult.summaryId } ? 1.0 : 0.0
            
            // Apply temporal filter
            if let temporalHint = parsedQuery.temporalHint {
                let dateRange = resolveTemporalHint(temporalHint)
                // For now, skip temporal filtering in simplified version
            }
            
            // Create a placeholder TextSummary - in production this would be properly joined
            let placeholderSummary = TextSummary(
                title: "Search Result \(vectorResult.summaryId.prefix(8))",
                content: "Content for \(vectorResult.summaryId)",
                summary: "Summary for \(vectorResult.summaryId)",
                keywords: parsedQuery.keywords
            )
            
            let combinedScore = semanticScore * 0.6 + keywordScore * 0.4
            
            filteredResults.append(QueryResult(
                summary: placeholderSummary,
                semanticScore: semanticScore,
                keywordScore: keywordScore,
                temporalScore: 1.0, // No temporal scoring in simplified version
                combinedScore: combinedScore,
                matchedKeywords: keywordScore > 0 ? parsedQuery.keywords : []
            ))
        }
        
        // Sort by combined score and limit
        return Array(filteredResults.sorted { $0.combinedScore > $1.combinedScore }.prefix(limit))
    }
    
    private func keywordScoreSQL(for keywords: [String]) -> String {
        // Generate SQL for keyword scoring
        let conditions = keywords.map { _ in "ts.keywords LIKE ?" }
        return "(\(conditions.joined(separator: " + ")))"
    }
    
    private func resolveTemporalHint(_ hint: TemporalHint) -> (start: Date?, end: Date?) {
        let calendar = Calendar.current
        let now = Date()
        
        switch hint.type {
        case .relative:
            switch hint.value.lowercased() {
            case "yesterday":
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
                let startOfDay = calendar.startOfDay(for: yesterday)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                return (startOfDay, endOfDay)
                
            case "last week":
                let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
                return (lastWeek, now)
                
            case "last month":
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
                return (lastMonth, now)
                
            default:
                return (nil, nil)
            }
            
        case .absolute:
            // Handle absolute dates like "June 2024", "2024-06-15"
            let formatter = DateFormatter()
            
            // Try different date formats
            let formats = ["yyyy-MM-dd", "MMMM yyyy", "MMMM dd"]
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: hint.value) {
                    let startOfDay = calendar.startOfDay(for: date)
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    return (startOfDay, endOfDay)
                }
            }
            
            return (nil, nil)
        }
    }
}

// MARK: - Query Parser

class QueryParser {
    private let tagger: NLTagger
    private let intentKeywords: [QueryIntent: Set<String>]
    
    init() {
        self.tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        
        self.intentKeywords = [
            .search: Set(["find", "search", "look", "get", "where"]),
            .show: Set(["show", "display", "present", "reveal"]),
            .list: Set(["list", "enumerate", "all", "every"]),
            .analyze: Set(["analyze", "review", "examine", "study"])
        ]
    }
    
    func parse(_ queryText: String) -> ParsedQuery {
        let trimmedQuery = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Extract intent
        let intent = extractIntent(from: trimmedQuery)
        
        // Extract keywords (nouns, adjectives, important terms)
        let keywords = extractKeywords(from: trimmedQuery)
        
        // Extract entities (people, places, organizations)
        let entities = extractEntities(from: trimmedQuery)
        
        // Extract temporal hints
        let temporalHint = extractTemporalHint(from: trimmedQuery)
        
        return ParsedQuery(
            originalText: trimmedQuery,
            intent: intent,
            keywords: keywords,
            entities: entities,
            temporalHint: temporalHint
        )
    }
    
    private func extractIntent(from text: String) -> QueryIntent {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        for (intent, keywords) in intentKeywords {
            if words.contains(where: { keywords.contains($0) }) {
                return intent
            }
        }
        
        return .search // Default intent
    }
    
    private func extractKeywords(from text: String) -> [String] {
        tagger.string = text
        
        var keywords: [String] = []
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "from", "me", "my", "all", "about"])
        
        let tags = tagger.tags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation])
        
        for (tag, range) in tags {
            if let tag = tag, tag == .noun || tag == .adjective {
                let word = String(text[range]).lowercased()
                if !stopWords.contains(word) && word.count > 2 {
                    keywords.append(word)
                }
            }
        }
        
        return Array(Set(keywords)) // Remove duplicates
    }
    
    private func extractEntities(from text: String) -> [String] {
        tagger.string = text
        
        var entities: [String] = []
        
        let tags = tagger.tags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .nameType,
                             options: [.omitWhitespace, .omitPunctuation])
        
        for (tag, range) in tags {
            if let tag = tag, tag == .personalName || tag == .placeName || tag == .organizationName {
                let entity = String(text[range]).lowercased()
                entities.append(entity)
            }
        }
        
        return Array(Set(entities)) // Remove duplicates
    }
    
    private func extractTemporalHint(from text: String) -> TemporalHint? {
        let temporalPatterns: [(String, TemporalHint.HintType)] = [
            // Relative patterns
            ("yesterday", .relative),
            ("last week", .relative),
            ("last month", .relative),
            ("this morning", .relative),
            ("today", .relative),
            
            // Month names
            ("january", .absolute),
            ("february", .absolute),
            ("march", .absolute),
            ("april", .absolute),
            ("may", .absolute),
            ("june", .absolute),
            ("july", .absolute),
            ("august", .absolute),
            ("september", .absolute),
            ("october", .absolute),
            ("november", .absolute),
            ("december", .absolute)
        ]
        
        for (pattern, type) in temporalPatterns {
            if text.contains(pattern) {
                return TemporalHint(type: type, value: pattern, resolvedDate: nil)
            }
        }
        
        // Look for date patterns like "2024-06-15"
        let dateRegex = try? NSRegularExpression(pattern: "\\d{4}-\\d{2}-\\d{2}")
        if let regex = dateRegex {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                let dateString = String(text[Range(match.range, in: text)!])
                return TemporalHint(type: .absolute, value: dateString, resolvedDate: nil)
            }
        }
        
        return nil
    }
}

// MARK: - Supporting Types

struct ParsedQuery {
    let originalText: String
    let intent: QueryIntent
    let keywords: [String]
    let entities: [String]
    let temporalHint: TemporalHint?
}

enum QueryIntent {
    case search
    case show
    case list
    case analyze
}

struct TemporalHint {
    enum HintType {
        case relative // "yesterday", "last week"
        case absolute // "June 2024", "2024-06-15"
    }
    
    let type: HintType
    let value: String
    let resolvedDate: Date?
}

struct QueryResult {
    let summary: TextSummary
    let semanticScore: Double
    let keywordScore: Double
    let temporalScore: Double
    let combinedScore: Double
    let matchedKeywords: [String]
}

enum QueryEngineError: Error {
    case databaseNotAvailable
    case embeddingGenerationFailed
    case queryParsingFailed(String)
    case searchExecutionFailed(String)
}

extension QueryEngineError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .databaseNotAvailable:
            return "Database is not available"
        case .embeddingGenerationFailed:
            return "Failed to generate embedding for query"
        case .queryParsingFailed(let message):
            return "Query parsing failed: \(message)"
        case .searchExecutionFailed(let message):
            return "Search execution failed: \(message)"
        }
    }
}