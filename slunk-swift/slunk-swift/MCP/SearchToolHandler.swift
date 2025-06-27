import Foundation

// MARK: - Search Tool Handler

class SearchToolHandler: BaseMCPToolHandler {
    
    private let database: SlackDatabaseSchema?
    private let queryService: SlackQueryService?
    private let messageContextualizer: MessageContextualizer?
    
    override var supportedTools: [String] {
        get {
            return ["searchConversations", "search_messages", "conversational_search"]
        }
        set {
            // No-op, this property is read-only for this handler
        }
    }
    
    init(database: SlackDatabaseSchema?, queryService: SlackQueryService?, messageContextualizer: MessageContextualizer?) {
        self.database = database
        self.queryService = queryService
        self.messageContextualizer = messageContextualizer
    }
    
    override func handle(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        // This method should not be called directly, use the specific tool methods
        return createError(
            code: -32601,
            message: "Method not implemented",
            id: id
        )
    }
    
    // MARK: - Search Conversations Tool
    
    func handleSearchConversations(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        guard let database = database else {
            return createError(
                code: -32603,
                message: "Search service temporarily unavailable. The database is not initialized. This usually resolves within a few seconds after app startup. Please try again in a moment, or check if the Slack monitoring service is running.",
                id: id
            )
        }
        
        guard let query = extractStringParameter("query", from: arguments) else {
            return createError(
                code: -32602,
                message: "Missing required parameter 'query'. Please provide a search query string. Example: {\"query\": \"Swift discussions with Alice from last week\"}. The query should be in natural language describing what you want to find.",
                id: id
            )
        }
        
        let limit = extractIntParameter("limit", from: arguments, defaultValue: 10) ?? 10
        
        do {
            // Use hybrid search for better semantic matching
            let results = try await database.hybridSearchWithQuery(
                query: query,
                limit: limit
            )
            
            let searchResults = results.map { result in
                [
                    "id": result.message.id,
                    "title": "Message from \(result.message.sender)",
                    "summary": String(result.message.content.prefix(200)),
                    "sender": result.message.sender,
                    "timestamp": ISO8601DateFormatter().string(from: result.message.timestamp),
                    "channel": result.message.channel,
                    "workspace": result.workspace
                ] as [String: Any]
            }
            
            // Provide helpful guidance for empty results
            let result: Any = searchResults.isEmpty ? 
                createEmptyResultsGuidance(query: query) :
                searchResults
            
            return JSONRPCResponse(
                result: result,
                error: nil,
                id: id
            )
            
        } catch {
            return createError(
                code: -32603,
                message: "Search failed: \(error.localizedDescription). Try simplifying your query, using different keywords, or try the 'search_messages' tool for more specific searches. If the error persists, the search service may need time to initialize.",
                id: id
            )
        }
    }
    
    // MARK: - Search Messages Tool
    
    func handleSearchMessages(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        guard let _ = queryService else {
            return createError(
                code: -32603,
                message: "Query service not available",
                id: id
            )
        }
        
        guard let query = extractStringParameter("query", from: arguments) else {
            return createError(
                code: -32602,
                message: "Missing required parameter 'query'",
                id: id
            )
        }
        
        // For now, return a placeholder response
        // TODO: Implement actual search logic when SlackQueryService search methods are available
        let searchResults: [[String: Any]] = []
        
        return JSONRPCResponse(
            result: [
                "results": searchResults,
                "query": query,
                "message": "Search messages functionality not yet implemented in extracted handler"
            ],
            error: nil,
            id: id
        )
    }
    
    // MARK: - Conversational Search Tool
    
    func handleConversationalSearch(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        // Implementation would be similar to other search methods
        // For now, return a placeholder response
        return createError(
            code: -32601,
            message: "Conversational search not yet implemented",
            id: id
        )
    }
    
    // MARK: - Helper Methods
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
}

// MARK: - Search Criteria Structure

struct SlackSearchCriteria {
    let query: String
    let channel: String?
    let sender: String?
    let startDate: Date?
    let endDate: Date?
    let limit: Int
}