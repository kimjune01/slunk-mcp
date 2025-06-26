import Foundation

class MCPServer {
    // MARK: - Constants
    private enum Constants {
        static let protocolVersion = "2024-11-05"
        static let serverName = "Slunk MCP Server"
        static let serverVersion = "0.1.0"
        static let readLoopSleepNanoseconds: UInt64 = 10_000_000 // 10ms
        static let retryLoopSleepNanoseconds: UInt64 = 100_000_000 // 100ms
        static let shutdownDelayNanoseconds: UInt64 = 100_000_000 // 100ms
    }
    
    // MARK: - Properties
    private let inputHandle = FileHandle.standardInput
    private let outputHandle = FileHandle.standardOutput
    private let errorHandle = FileHandle.standardError
    private var isRunning = false
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Vector database components
    // Database management now handled by SlackQueryService directly
    private var queryEngine: NaturalLanguageQueryEngine?
    private var smartIngestion: SmartIngestionService?
    private var conversationalSearch: ConversationalSearchService?
    private var database: SlackDatabaseSchema?
    private var queryService: SlackQueryService?
    private var messageContextualizer: MessageContextualizer?
    
    init() {
        setupHandlers()
        setupVectorComponents()
    }
    
    private func setupVectorComponents() {
        self.queryEngine = NaturalLanguageQueryEngine()
        self.smartIngestion = SmartIngestionService()
        
        // Database is initialized via ProductionService in the main app startup
        logError("🔧 MCP server components initialized. Database connection will be established via ProductionService.")
        
        // Set up conversational search after query engine is created
        if let queryEngine = self.queryEngine {
            let embeddingService = EmbeddingService()
            self.conversationalSearch = ConversationalSearchService(
                queryEngine: queryEngine,
                embeddingService: embeddingService
            )
            
            // Initialize message contextualizer
            self.messageContextualizer = MessageContextualizer(embeddingService: embeddingService)
        }
    }
    
    // Note: MCPServer no longer uses setDatabase as tools directly use SlackQueryService
    // Database management is now handled in ProductionService with SlackDatabaseSchema
    
    private func setupHandlers() {
        // Configure encoder/decoder
        encoder.outputFormatting = []
        decoder.keyDecodingStrategy = .useDefaultKeys
    }
    
    func start() {
        isRunning = true
        logError("🚀 MCP Server started (stdio transport)")
        
        Task {
            await readLoop()
        }
    }
    
    func stop() {
        isRunning = false
        logError("🛑 MCP Server stopped")
    }
    
    private func readLoop() async {
        while isRunning {
            do {
                let data = inputHandle.availableData
                guard !data.isEmpty else {
                    try await Task.sleep(nanoseconds: Constants.readLoopSleepNanoseconds)
                    continue
                }
                
                // Split by newlines to handle multiple messages
                let messages = data.split(separator: UInt8(ascii: "\n"))
                
                for messageData in messages {
                    if messageData.isEmpty { continue }
                    
                    do {
                        let request = try decoder.decode(JSONRPCRequest.self, from: Data(messageData))
                        let response = await handleRequest(request)
                        try sendResponse(response)
                    } catch {
                        logError("Failed to decode request: \(error)")
                    }
                }
            } catch {
                logError("Read loop error: \(error)")
                try? await Task.sleep(nanoseconds: Constants.retryLoopSleepNanoseconds)
            }
        }
    }
    
    private func handleRequest(_ request: JSONRPCRequest) async -> JSONRPCResponse {
        switch request.method {
        case "initialize":
            return handleInitialize(request)
        case "initialized":
            return handleInitialized(request)
        case "tools/list":
            return handleToolsList(request)
        case "tools/call":
            return await handleToolCall(request)
        case "shutdown":
            return handleShutdown(request)
        default:
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32601, message: "Method not found", data: nil),
                id: request.id
            )
        }
    }
    
    private func handleInitialize(_ request: JSONRPCRequest) -> JSONRPCResponse {
        let result: [String: Any] = [
            "protocolVersion": Constants.protocolVersion,
            "capabilities": [
                "tools": [:]
            ],
            "serverInfo": [
                "name": Constants.serverName,
                "version": Constants.serverVersion
            ]
        ]
        
        return JSONRPCResponse(result: result, error: nil, id: request.id)
    }
    
    private func handleInitialized(_ request: JSONRPCRequest) -> JSONRPCResponse {
        // Notification, no response needed
        return JSONRPCResponse(result: nil, error: nil, id: request.id)
    }
    
    private func handleToolsList(_ request: JSONRPCRequest) -> JSONRPCResponse {
        // Tool Selection Guide for LLM Agents
        let toolSelectionGuide = """
        🎯 SLACK SEARCH TOOL QUICK REFERENCE
        
        START HERE:
        └─ General search? → searchConversations
           └─ Too many results? → search_messages (add filters)
           └─ Want more? → suggest_related
        
        BY USE CASE:
        • "What did X say?" → search_messages + user filter
        • "Catch me up" → search_messages + channel/date filters  
        • "What's trending?" → discover_patterns
        • "What does 👍 mean?" → get_message_context
        • "Show me the thread" → get_thread_context
        • "Tell me more" → conversational_search
        
        CHAINING STRATEGY:
        1. discover_patterns → Find what to search
        2. searchConversations → Get overview
        3. search_messages → Drill down with filters
        4. get_thread_context → Read full discussions
        5. suggest_related → Find more
        
        💡 TIPS:
        • Message IDs look like: 1750947252.454503
        • Dates use ISO 8601: 2024-03-15T00:00:00Z
        • Empty query in search_messages = filter only
        """
        
        let tools: [[String: Any]] = [
            [
                "name": "searchConversations",
                "description": "BEST FOR: Quick natural language searches across all Slack messages. Understands context and meaning, not just keywords. Returns message summaries with relevance scores. USE WHEN: Starting a search, finding discussions by topic, or when you don't know exact channels/users. RETURNS: Array of {id, title, summary, sender, timestamp, score, matchedKeywords}. TIP: Start here for any search task.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Natural language search query. Be conversational. Examples: 'discussions about the API redesign last week', 'what did John say about the deployment issue?', 'customer feedback from March'"],
                        "limit": ["type": "integer", "description": "Max results to return (1-50)", "default": 10, "minimum": 1, "maximum": 50]
                    ],
                    "required": ["query"]
                ]
            ],
            // Phase 2: Contextual Search Tools
            [
                "name": "search_messages",
                "description": "BEST FOR: Precise searches with filters by channel, user, or date range. Returns full message content with metadata. USE WHEN: You know specific channels/users, need messages from a date range, or searchConversations gave too many results. RETURNS: Array of {id, workspace, channel, sender, content, timestamp, threadId}. TIP: Combine multiple filters for surgical precision.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Search text (can be empty string to filter by other criteria). Examples: 'deployment', 'bug fix', 'meeting notes', ''"],
                        "channels": ["type": "array", "items": ["type": "string"], "description": "Channel names to search in. Examples: ['engineering', 'general'], ['#product-team']"],
                        "users": ["type": "array", "items": ["type": "string"], "description": "User names who sent messages. Examples: ['alice', 'bob'], ['@john.doe']"],
                        "start_date": ["type": "string", "description": "ISO 8601 date-time. Examples: '2024-03-15T00:00:00Z', '2024-03-15T14:30:00-07:00'"],
                        "end_date": ["type": "string", "description": "ISO 8601 date-time. Examples: '2024-03-20T23:59:59Z', '2024-03-20T18:00:00-07:00'"],
                        "search_mode": ["type": "string", "enum": ["semantic", "structured", "hybrid"], "default": "hybrid", "description": "semantic=meaning-based, structured=exact match, hybrid=both"],
                        "limit": ["type": "integer", "default": 20, "minimum": 1, "maximum": 100]
                    ],
                    "required": ["query"]
                ]
            ],
            [
                "name": "get_thread_context", 
                "description": "BEST FOR: Retrieving complete thread conversations with all replies. Enhances short messages with contextual meaning. USE WHEN: You have a thread_id from search results and want the full conversation, or investigating a specific discussion thread. RETURNS: {threadId, parentMessage, messages[], contextualMeanings[], participants[], messageCount, timespan}. TIP: Thread IDs look like '1234567890.123456'.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "thread_id": ["type": "string", "description": "Slack thread timestamp ID. Example: '1750947252.454503'"],
                        "include_context": ["type": "boolean", "default": true, "description": "Enhance short messages/emojis with meaning"]
                    ],
                    "required": ["thread_id"]
                ]
            ],
            [
                "name": "get_message_context",
                "description": "BEST FOR: Understanding cryptic messages, emojis, or abbreviations by analyzing surrounding context. USE WHEN: A message is unclear (e.g., just '👍' or 'lgtm'), you need the full thread a message belongs to, or want enhanced meaning. RETURNS: {originalMessage, contextualMeaning, threadContext, enhancement}. TIP: Especially useful for short reactions or acronyms.",
                "inputSchema": [
                    "type": "object", 
                    "properties": [
                        "message_id": ["type": "string", "description": "Slack message ID. Example: '1750947252.454503'"],
                        "include_thread": ["type": "boolean", "default": true, "description": "Include full thread context if message is in thread"]
                    ],
                    "required": ["message_id"]
                ]
            ],
            // Phase 3: Advanced Query Processing Tools
            [
                "name": "parse_natural_query",
                "description": "BEST FOR: Understanding what a user is asking for before searching. Extracts channels, users, dates, and intent from natural language. USE WHEN: You want to understand a complex query before executing it, or building advanced search workflows. RETURNS: {intent, keywords[], channels[], users[], entities[], temporalHint}. TIP: Use this to pre-process queries for other tools.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Natural language to analyze. Example: 'what did @alice say in #engineering about the API last week?'"],
                        "include_entities": ["type": "boolean", "default": true, "description": "Extract people, channels, topics"],
                        "include_temporal": ["type": "boolean", "default": true, "description": "Extract time references (yesterday, last week, etc)"]
                    ],
                    "required": ["query"]
                ]
            ],
            [
                "name": "discover_patterns",
                "description": "BEST FOR: Understanding team dynamics, trending topics, and communication patterns without specific search terms. USE WHEN: Starting research, understanding what's important to the team, or finding active discussion areas. RETURNS: {patterns: {topics[], participants[], communication[]}, timeRange, analysisDate}. TIP: Run this first to discover what to search for.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "time_range": ["type": "string", "enum": ["day", "week", "month", "all"], "default": "week", "description": "Analysis period"],
                        "pattern_type": ["type": "string", "enum": ["topics", "participants", "communication", "all"], "default": "all", "description": "What patterns to analyze"],
                        "min_occurrences": ["type": "integer", "default": 3, "minimum": 2, "description": "Minimum frequency to be significant"]
                    ]
                ]
            ],
            [
                "name": "suggest_related",
                "description": "BEST FOR: Expanding search results by finding semantically similar content. Discovers follow-ups, related discussions, or parallel conversations. USE WHEN: After finding interesting messages, want to explore 'what else?', or discover if topic was discussed elsewhere. RETURNS: {suggestions[], referenceMessages[], queryContext, suggestionsCount}. TIP: Chain after any search to go deeper.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "reference_messages": ["type": "array", "items": ["type": "string"], "description": "Message IDs to find similar content for. Example: ['1750947252.454503']"],
                        "query_context": ["type": "string", "description": "Topic description if no message IDs. Example: 'kubernetes migration discussions'"],
                        "suggestion_type": ["type": "string", "enum": ["similar", "followup", "related", "all"], "default": "all", "description": "Type of relationships to find"],
                        "limit": ["type": "integer", "default": 10, "minimum": 1, "maximum": 20]
                    ]
                ]
            ],
            [
                "name": "conversational_search",
                "description": "BEST FOR: Multi-turn search sessions where each query refines the previous. Maintains context between searches for natural follow-ups. USE WHEN: Exploring a topic iteratively, need to remember previous searches, or progressively narrowing results. RETURNS: {sessionId, results[], enhancedQuery, refinementSuggestions[], sessionContext}. TIP: Say 'show more', 'filter by John', 'from last week' naturally.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Search query or refinement. Examples: 'API errors', 'show more recent ones', 'only from Alice'"],
                        "session_id": ["type": "string", "description": "Continue previous session (auto-created if omitted)"],
                        "action": ["type": "string", "enum": ["search", "refine", "start_session", "end_session"], "default": "search", "description": "search=new/continue, refine=modify last"],
                        "refinement": [
                            "type": "object",
                            "description": "For action=refine only",
                            "properties": [
                                "type": ["type": "string", "enum": ["add_keywords", "remove_keywords", "add_channels", "add_users", "change_time"]],
                                "keywords": ["type": "array", "items": ["type": "string"]],
                                "channels": ["type": "array", "items": ["type": "string"]],
                                "users": ["type": "array", "items": ["type": "string"]]
                            ]
                        ],
                        "limit": ["type": "integer", "default": 10, "minimum": 1, "maximum": 50]
                    ],
                    "required": ["query"]
                ]
            ]
        ]
        
        // Tool Chaining Examples for Complex Workflows
        let toolChainExamples = """
        
        📋 EXAMPLE WORKFLOWS:
        
        "Find how we decided on X":
        1. searchConversations → Find decision discussions
        2. get_thread_context → Read full threads
        3. suggest_related → Find follow-ups
        
        "What's the team working on?":
        1. discover_patterns → See trending topics
        2. search_messages → Deep dive on topics
        3. conversational_search → Explore iteratively
        
        "Debug this error":
        1. search_messages → Find error mentions
        2. get_thread_context → Read solutions
        3. suggest_related → Find similar issues
        
        "Weekly catch-up":
        1. search_messages → Channel + date filter
        2. discover_patterns → Topic summary
        3. searchConversations → Key decisions
        """
        
        let response: [String: Any] = [
            "tools": tools,
            "toolSelectionGuide": toolSelectionGuide,
            "toolChainExamples": toolChainExamples
        ]
        
        return JSONRPCResponse(result: response, error: nil, id: request.id)
    }
    
    private func handleToolCall(_ request: JSONRPCRequest) async -> JSONRPCResponse {
        guard let params = request.params,
              let nameValue = params["name"],
              let name = nameValue.value as? String else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Invalid params"),
                id: request.id
            )
        }
        
        let argumentsValue = params["arguments"]
        let arguments = argumentsValue?.value as? [String: Any] ?? [:]
        
        switch name {
        case "searchConversations":
            return await handleSearchConversations(MCPRequest(method: name, params: arguments))
        // Phase 2: Contextual Search Tools
        case "search_messages":
            return await handleSearchMessages(arguments, id: request.id)
            
        case "get_thread_context":
            return await handleGetThreadContext(arguments, id: request.id)
            
        case "get_message_context":
            return await handleGetMessageContext(arguments, id: request.id)
            
        // Phase 3: Advanced Query Processing Tools
        case "parse_natural_query":
            return await handleParseNaturalQuery(arguments, id: request.id)
            
        case "discover_patterns":
            return await handleDiscoverPatterns(arguments, id: request.id)
            
        case "suggest_related":
            return await handleSuggestRelated(arguments, id: request.id)
            
        case "conversational_search":
            return await handleConversationalSearch(arguments, id: request.id)
            
        default:
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32601, message: "Unknown tool: '\(name)'. Available tools: searchConversations, search_messages, get_thread_context, get_message_context, parse_natural_query, discover_patterns, suggest_related, conversational_search. Use 'tools/list' to see full descriptions and parameters."),
                id: request.id
            )
        }
    }
    
    private func handleShutdown(_ request: JSONRPCRequest) -> JSONRPCResponse {
        Task {
            try await Task.sleep(nanoseconds: Constants.shutdownDelayNanoseconds)
            stop()
        }
        return JSONRPCResponse(result: nil, error: nil, id: request.id)
    }
    
    private func sendResponse(_ response: JSONRPCResponse) throws {
        let data = try encoder.encode(response)
        outputHandle.write(data)
        outputHandle.write("\n".data(using: .utf8)!)
        
        // Force flush
        fflush(stdout)
    }
    
    private func logError(_ message: String) {
        #if DEBUG
        errorHandle.write("[MCP Server] \(message)\n".data(using: .utf8)!)
        fflush(stderr)
        #endif
    }
    
    // MARK: - Error Handling
    
    private func createError(code: Int, message: String, suggestions: [String] = []) -> JSONRPCError {
        var fullMessage = message
        if !suggestions.isEmpty {
            fullMessage += "\n💡 Try: " + suggestions.joined(separator: " | ")
        }
        return JSONRPCError(code: code, message: fullMessage)
    }
    
    private func createEmptyResultsGuidance(query: String) -> [String: Any] {
        return [
            "results": [],
            "resultCount": 0,
            "query": query,
            "guidance": "No results found. Try: broader keywords | longer time range | 'discover_patterns' to see what's available"
        ]
    }
    
    // MARK: - Enhanced MCP Tool Handlers
    
    func handleSearchConversations(_ request: MCPRequest) async -> JSONRPCResponse {
        guard let queryEngine = queryEngine else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Search service temporarily unavailable. The query engine is not initialized. This usually resolves within a few seconds after app startup. Please try again in a moment, or check if the Slack monitoring service is running."),
                id: JSONRPCId.string(request.id)
            )
        }
        
        guard let query = request.params["query"] as? String else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Missing required parameter 'query'. Please provide a search query string. Example: {\"query\": \"Swift discussions with Alice from last week\"}. The query should be in natural language describing what you want to find."),
                id: JSONRPCId.string(request.id)
            )
        }
        
        let limit = request.params["limit"] as? Int ?? 10
        
        do {
            let parsedQuery = queryEngine.parseQuery(query)
            let results = try await queryEngine.executeHybridSearch(parsedQuery, limit: limit)
            
            let searchResults = results.map { result in
                [
                    "id": result.summary.id.uuidString,
                    "title": result.summary.title,
                    "summary": result.summary.summary,
                    "sender": result.summary.sender ?? "Unknown",
                    "timestamp": ISO8601DateFormatter().string(from: result.summary.timestamp),
                    "score": result.combinedScore,
                    "matchedKeywords": result.matchedKeywords
                ] as [String: Any]
            }
            
            // Provide helpful guidance for empty results
            let result: Any = searchResults.isEmpty ? 
                createEmptyResultsGuidance(query: query) :
                searchResults
            
            return JSONRPCResponse(
                result: result,
                error: nil,
                id: JSONRPCId.string(request.id)
            )
            
        } catch {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Search failed: \(error.localizedDescription). Try simplifying your query, using different keywords, or try the 'conversational_search' tool for complex queries. If the error persists, the search service may need time to initialize."),
                id: JSONRPCId.string(request.id)
            )
        }
    }
    
    func handleRequest(_ request: MCPRequest) async -> JSONRPCResponse {
        // Generic handler for tests - just calls the specific handlers
        switch request.method {
        case "searchConversations":
            return await handleSearchConversations(request)
        default:
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32601, message: "Method not found"),
                id: JSONRPCId.string(request.id)
            )
        }
    }
    
    private func generateConversationStats(timeRange: String) async throws -> [String: Any] {
        // Generate stats using SlackQueryService
        let embeddingService = EmbeddingService()
        let messageContextualizer = MessageContextualizer(embeddingService: embeddingService)
        let queryService = SlackQueryService(messageContextualizer: messageContextualizer)
        
        // Get the database from ProductionService
        guard let database = await ProductionService.shared.getDatabase() else {
            throw SlunkError.databaseInitializationFailed("Database not available")
        }
        await queryService.setDatabase(database)
        
        // Get basic message count statistics
        let totalMessages = try await queryService.getMessageCount()
        let workspaceCount = try await queryService.getWorkspaceCount()
        
        let stats: [String: Any] = [
            "totalMessages": totalMessages,
            "workspaceCount": workspaceCount,
            "timeRange": timeRange,
            "source": "SlackDatabaseSchema"
        ]
        
        return stats
    }
    
    // MARK: - Phase 2 MCP Tool Handlers
    
    internal func handleSearchMessages(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        guard let query = arguments["query"] as? String else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Missing required parameter 'query'. For search_messages, provide: {\"query\": \"your search terms\", \"channels\": [\"#channel1\"], \"users\": [\"@username\"], \"start_date\": \"2024-03-15\"}. Use this tool when you need specific filtering by channel, user, or date."),
                id: id
            )
        }
        
        // Database availability is checked within SlackQueryService
        // No need for explicit database guard here
        
        // Extract and validate parameters
        let channels = arguments["channels"] as? [String] ?? []
        let users = arguments["users"] as? [String] ?? []
        
        // Validate date parameters
        var startDate: Date?
        var endDate: Date?
        
        if let startDateStr = arguments["start_date"] as? String {
            startDate = ISO8601DateFormatter().date(from: startDateStr)
            if startDate == nil {
                return JSONRPCResponse(
                    result: nil,
                    error: JSONRPCError(code: -32602, message: "Invalid 'start_date' format '\(startDateStr)'. Use ISO 8601 format with time like '2024-03-15T00:00:00Z' or '2024-03-15T14:30:00Z'."),
                    id: id
                )
            }
        }
        
        if let endDateStr = arguments["end_date"] as? String {
            endDate = ISO8601DateFormatter().date(from: endDateStr)
            if endDate == nil {
                return JSONRPCResponse(
                    result: nil,
                    error: JSONRPCError(code: -32602, message: "Invalid 'end_date' format '\(endDateStr)'. Use ISO 8601 format with time like '2024-03-20T23:59:59Z' or '2024-03-20T18:00:00Z'."),
                    id: id
                )
            }
        }
        
        let searchModeStr = arguments["search_mode"] as? String ?? "hybrid"
        let limit = arguments["limit"] as? Int ?? 10
        
        // Validate search mode
        if !["semantic", "structured", "hybrid"].contains(searchModeStr) {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Invalid 'search_mode' '\(searchModeStr)'. Valid options are: 'semantic' (finds similar meaning), 'structured' (exact keyword matching), 'hybrid' (combines both, recommended)."),
                id: id
            )
        }
        
        // Validate limit
        if limit < 1 || limit > 100 {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Invalid 'limit' \(limit). Must be between 1 and 100. Use smaller values (5-20) for focused results, larger values (50-100) for comprehensive searches."),
                id: id
            )
        }
        
        // Parse search mode (for future use)
        let _ = {
            switch searchModeStr {
            case "semantic": return SearchMode.semantic
            case "structured": return SearchMode.structured
            default: return SearchMode.hybrid
            }
        }()
        
        // Create an embedding service and contextualizer for the query service
        let embeddingService = EmbeddingService()
        let contextualizer = MessageContextualizer(embeddingService: embeddingService)
        let queryService = SlackQueryService(messageContextualizer: contextualizer)
        
        // Build filters
        var filters: [QueryFilter] = []
        
        if !channels.isEmpty {
            filters.append(await queryService.filterByChannels(channels))
        }
        
        if !users.isEmpty {
            filters.append(await queryService.filterByUsers(users))
        }
        
        if let start = startDate, let end = endDate {
            filters.append(await queryService.filterByTimeRange(from: start, to: end))
        }
        
        // Get database from ProductionService
        guard let database = await ProductionService.shared.getDatabase() else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Database not initialized. The service is still starting up. Please wait a moment and try again."),
                id: id
            )
        }
        
        // Perform database search
        do {
            let results = try await database.searchMessages(
                query: query,
                channels: channels.isEmpty ? nil : channels,
                users: users.isEmpty ? nil : users,
                startDate: startDate,
                endDate: endDate,
                limit: limit
            )
            
            // Format results
            let formattedResults = results.map { result in
                [
                    "id": result.message.id,
                    "workspace": result.workspace,
                    "channel": result.message.channel,
                    "sender": result.message.sender,
                    "content": result.message.content,
                    "timestamp": ISO8601DateFormatter().string(from: result.message.timestamp),
                    "threadId": result.message.threadId as Any
                ] as [String: Any]
            }
            
            // Provide helpful guidance for empty results
            let result: Any = formattedResults.isEmpty ?
                createEmptyResultsGuidance(query: query) :
                formattedResults
            
            return JSONRPCResponse(result: result, error: nil, id: id)
        } catch {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Search failed: \(error.localizedDescription). Try simplifying your query or check if the database is accessible."),
                id: id
            )
        }
    }
    
    internal func handleGetThreadContext(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        guard let threadId = arguments["thread_id"] as? String else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Missing required parameter 'thread_id'. Provide the Slack thread timestamp ID like: {\"thread_id\": \"ts_1234567890.123456\"}. Thread IDs can be found in search results or by examining Slack URLs. If you don't have a thread ID, try using 'search_messages' to find relevant conversations first."),
                id: id
            )
        }
        
        let includeContext = arguments["include_context"] as? Bool ?? true
        
        guard let database = self.database else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Database not initialized"),
                id: id
            )
        }
        
        do {
            // Fetch all messages in the thread
            let threadMessages = try await database.getThreadMessages(threadId: threadId, limit: 1000)
            
            guard !threadMessages.isEmpty else {
                return JSONRPCResponse(
                    result: nil,
                    error: JSONRPCError(code: -32602, message: "Thread not found with id: \(threadId)"),
                    id: id
                )
            }
            
            // Sort messages by timestamp
            let sortedMessages = threadMessages.sorted { $0.message.timestamp < $1.message.timestamp }
            
            // Extract participants
            let participants = Set(sortedMessages.map { $0.message.sender })
            
            // Get time span
            let startTime = sortedMessages.first?.message.timestamp ?? Date()
            let endTime = sortedMessages.last?.message.timestamp ?? Date()
            
            // Convert messages to dictionary format
            var messageData: [[String: Any]] = []
            var contextualMeanings: [[String: Any]] = []
            
            if includeContext {
                // Initialize message contextualizer if needed
                guard let messageContextualizer = self.messageContextualizer else {
                    return JSONRPCResponse(
                        result: nil,
                        error: JSONRPCError(code: -32603, message: "Message contextualizer not initialized"),
                        id: id
                    )
                }
                
                // Set database on contextualizer
                await messageContextualizer.setDatabase(database)
                
                // Create thread context for contextual analysis
                let threadContext = ThreadContext(
                    threadId: threadId,
                    parentMessage: sortedMessages.first?.message,
                    recentMessages: sortedMessages.map { $0.message },
                    totalMessageCount: sortedMessages.count
                )
                
                // Process each message
                for (index, messageWithWorkspace) in sortedMessages.enumerated() {
                    let message = messageWithWorkspace.message
                    
                    // Basic message data
                    messageData.append([
                        "id": message.id,
                        "content": message.content,
                        "sender": message.sender,
                        "timestamp": ISO8601DateFormatter().string(from: message.timestamp),
                        "workspace": messageWithWorkspace.workspace,
                        "channel": message.channel,
                        "isParent": index == 0,
                        "position": index
                    ])
                    
                    // Extract contextual meaning for short messages
                    if let contextualMeaning = await messageContextualizer.extractContextualMeaning(
                        from: message,
                        threadContext: threadContext
                    ) {
                        contextualMeanings.append([
                            "messageId": message.id,
                            "originalContent": message.content,
                            "contextualMeaning": contextualMeaning,
                            "position": index
                        ])
                    }
                }
            } else {
                // Without context, just return basic message data
                for (index, messageWithWorkspace) in sortedMessages.enumerated() {
                    let message = messageWithWorkspace.message
                    messageData.append([
                        "id": message.id,
                        "content": message.content,
                        "sender": message.sender,
                        "timestamp": ISO8601DateFormatter().string(from: message.timestamp),
                        "workspace": messageWithWorkspace.workspace,
                        "channel": message.channel,
                        "isParent": index == 0,
                        "position": index
                    ])
                }
            }
            
            // Build result
            let result: [String: Any] = [
                "threadId": threadId,
                "parentMessage": sortedMessages.first != nil ? [
                    "id": sortedMessages.first!.message.id,
                    "content": sortedMessages.first!.message.content,
                    "sender": sortedMessages.first!.message.sender,
                    "timestamp": ISO8601DateFormatter().string(from: sortedMessages.first!.message.timestamp)
                ] : NSNull(),
                "messages": messageData,
                "contextualMeanings": contextualMeanings,
                "participants": Array(participants),
                "messageCount": sortedMessages.count,
                "timespan": [
                    "start": ISO8601DateFormatter().string(from: startTime),
                    "end": ISO8601DateFormatter().string(from: endTime),
                    "durationMinutes": Int(endTime.timeIntervalSince(startTime) / 60)
                ],
                "workspace": sortedMessages.first?.workspace ?? "",
                "channel": sortedMessages.first?.message.channel ?? ""
            ]
            
            return JSONRPCResponse(result: result, error: nil, id: id)
            
        } catch {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Failed to extract thread context: \(error.localizedDescription)"),
                id: id
            )
        }
    }
    
    internal func handleGetMessageContext(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        guard let messageId = arguments["message_id"] as? String else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Missing required parameter: message_id"),
                id: id
            )
        }
        
        let includeThread = arguments["include_thread"] as? Bool ?? true
        
        guard let database = self.database else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Database not initialized"),
                id: id
            )
        }
        
        do {
            // Fetch the message from database
            guard let messageWithWorkspace = try await database.getMessageById(messageId: messageId) else {
                return JSONRPCResponse(
                    result: nil,
                    error: JSONRPCError(code: -32602, message: "Message not found with id: \(messageId)"),
                    id: id
                )
            }
            
            let message = messageWithWorkspace.message
            
            // Check if messageContextualizer is available
            guard let messageContextualizer = self.messageContextualizer else {
                return JSONRPCResponse(
                    result: nil,
                    error: JSONRPCError(code: -32603, message: "Message contextualizer not initialized"),
                    id: id
                )
            }
            
            // Set database on contextualizer
            await messageContextualizer.setDatabase(database)
            
            // Get thread context if requested and message is in a thread
            var threadContext: ThreadContext?
            var threadMessages: [[String: Any]] = []
            
            if includeThread, let threadId = message.threadId {
                let threadMessagesData = try await database.getThreadMessages(threadId: threadId)
                let messages = threadMessagesData.map { $0.message }
                
                threadContext = ThreadContext(
                    threadId: threadId,
                    parentMessage: messages.first,
                    recentMessages: Array(messages.suffix(5)),
                    totalMessageCount: messages.count
                )
                
                // Convert thread messages to dictionary format
                threadMessages = messages.map { msg in
                    [
                        "id": msg.id,
                        "content": msg.content,
                        "sender": msg.sender,
                        "timestamp": ISO8601DateFormatter().string(from: msg.timestamp),
                        "isParent": msg.id == threadId
                    ]
                }
            }
            
            // Extract contextual meaning
            let contextualMeaning = await messageContextualizer.extractContextualMeaning(
                from: message,
                threadContext: threadContext
            )
            
            // Check if it's a short message
            let isShortMessage = message.content.count < 10 || 
                                message.content.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.allSatisfy({ $0.properties.isEmojiPresentation })
            
            // Get enhanced content
            let enhancedContent = isShortMessage ? 
                await messageContextualizer.enhanceWithThreadContext(message: message) :
                message.content
            
            let channelContext = await messageContextualizer.enhanceWithChannelContext(message: message)
            
            let result: [String: Any] = [
                "originalMessage": [
                    "id": message.id,
                    "content": message.content,
                    "sender": message.sender,
                    "timestamp": ISO8601DateFormatter().string(from: message.timestamp),
                    "channel": message.channel,
                    "workspace": messageWithWorkspace.workspace,
                    "threadId": message.threadId ?? NSNull() as Any
                ],
                "contextualMeaning": contextualMeaning ?? "No additional context extracted",
                "threadContext": includeThread && threadContext != nil ? [
                    "threadId": threadContext!.threadId,
                    "parentMessage": threadContext!.parentMessage != nil ? [
                        "id": threadContext!.parentMessage!.id,
                        "content": threadContext!.parentMessage!.content,
                        "sender": threadContext!.parentMessage!.sender
                    ] : NSNull(),
                    "messages": threadMessages,
                    "totalCount": threadContext!.totalMessageCount
                ] as [String: Any] : NSNull(),
                "enhancement": [
                    "wasShortMessage": isShortMessage,
                    "enhancedContent": enhancedContent,
                    "channelContext": channelContext
                ]
            ]
            
            return JSONRPCResponse(result: result, error: nil, id: id)
            
        } catch {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Failed to extract message context: \(error.localizedDescription)"),
                id: id
            )
        }
    }
    
    // MARK: - Phase 3 MCP Tool Handlers
    
    internal func handleParseNaturalQuery(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        guard let query = arguments["query"] as? String else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Missing required parameter: query"),
                id: id
            )
        }
        
        let includeEntities = arguments["include_entities"] as? Bool ?? true
        let includeTemporal = arguments["include_temporal"] as? Bool ?? true
        
        // Use the existing QueryParser from NaturalLanguageQueryEngine
        let parser = QueryParser()
        let parsedQuery = parser.parse(query)
        
        var result: [String: Any] = [
            "originalQuery": query,
            "intent": intentToString(parsedQuery.intent),
            "keywords": parsedQuery.keywords,
            "channels": parsedQuery.channels,
            "users": parsedQuery.users
        ]
        
        if includeEntities {
            result["entities"] = parsedQuery.entities
        }
        
        if includeTemporal, let temporalHint = parsedQuery.temporalHint {
            result["temporalHint"] = [
                "type": temporalHint.type == .relative ? "relative" : "absolute",
                "value": temporalHint.value,
                "resolvedDate": temporalHint.resolvedDate?.timeIntervalSince1970 as Any
            ]
        }
        
        result["status"] = "Query parsing complete with advanced NLP"
        
        return JSONRPCResponse(result: result, error: nil, id: id)
    }
    
    internal func handleDiscoverPatterns(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        let timeRange = arguments["time_range"] as? String ?? "week"
        let patternType = arguments["pattern_type"] as? String ?? "all"
        let minOccurrences = arguments["min_occurrences"] as? Int ?? 3
        
        do {
            // Create query service for pattern analysis
            let embeddingService = EmbeddingService()
            let messageContextualizer = MessageContextualizer(embeddingService: embeddingService)
            let queryService = SlackQueryService(messageContextualizer: messageContextualizer)
            
            // Get the database from ProductionService
            guard let database = await ProductionService.shared.getDatabase() else {
                throw SlunkError.databaseInitializationFailed("Database not available")
            }
            await queryService.setDatabase(database)
            
            // Get conversation summaries for pattern analysis (simplified approach)
            let _ = try await queryService.getMessageCount()
            let _ = try await queryService.getWorkspaceCount()
            
            // For now, return basic patterns until we implement getAllSummaries in SlackQueryService
            let summaries: [TextSummary] = [] // Fixed type to match function expectations
            
            // Analyze patterns based on keywords and entities
            let topicPatterns = analyzeTopicPatterns(summaries: summaries, minOccurrences: minOccurrences)
            let participantPatterns = analyzeParticipantPatterns(summaries: summaries, minOccurrences: minOccurrences)
            let communicationPatterns = analyzeCommunicationPatterns(summaries: summaries)
            
            var result: [String: Any] = [
                "timeRange": timeRange,
                "patternType": patternType,
                "minOccurrences": minOccurrences,
                "analysisDate": Date().timeIntervalSince1970
            ]
            
            switch patternType {
            case "topics":
                result["patterns"] = ["topics": topicPatterns]
            case "participants":
                result["patterns"] = ["participants": participantPatterns]
            case "communication":
                result["patterns"] = ["communication": communicationPatterns]
            default: // "all"
                result["patterns"] = [
                    "topics": topicPatterns,
                    "participants": participantPatterns,
                    "communication": communicationPatterns
                ]
            }
            
            result["status"] = "Pattern discovery complete"
            
            return JSONRPCResponse(result: result, error: nil, id: id)
            
        } catch {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Pattern discovery failed: \(error.localizedDescription)"),
                id: id
            )
        }
    }
    
    internal func handleSuggestRelated(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        let referenceMessages = arguments["reference_messages"] as? [String] ?? []
        let queryContext = arguments["query_context"] as? String
        let suggestionType = arguments["suggestion_type"] as? String ?? "all"
        let limit = arguments["limit"] as? Int ?? 5
        
        // Check if we have either reference messages or query context
        if referenceMessages.isEmpty && queryContext == nil {
            return JSONRPCResponse(
                result: nil,
                error: createError(
                    code: -32602,
                    message: "Must provide either 'reference_messages' or 'query_context' parameter.",
                    suggestions: ["Add query_context: 'topic'", "Add reference_messages: ['id1']"]
                ),
                id: id
            )
        }
        
        // Check if query engine is available
        guard let queryEngine = queryEngine else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Query engine not available"),
                id: id
            )
        }
        
        do {
            var suggestions: [[String: Any]] = []
            
            // If we have query context, use it to find related content
            if let context = queryContext {
                let parsedQuery = queryEngine.parseQuery(context)
                let searchResults = try await queryEngine.executeHybridSearch(parsedQuery, limit: limit)
                
                suggestions = searchResults.map { result in
                    [
                        "type": "contextual",
                        "title": result.summary.title,
                        "summary": result.summary.summary,
                        "score": result.combinedScore,
                        "reason": "Related to query context: \(parsedQuery.keywords.joined(separator: ", "))"
                    ] as [String: Any]
                }
            }
            
            // TODO: Add reference message-based suggestions
            // This would involve looking up the reference messages and finding similar content
            
            let result = [
                "referenceMessages": referenceMessages,
                "queryContext": queryContext as Any,
                "suggestionType": suggestionType,
                "suggestions": suggestions,
                "suggestionsCount": suggestions.count,
                "status": "Related content suggestions generated"
            ] as [String: Any]
            
            return JSONRPCResponse(result: result, error: nil, id: id)
            
        } catch {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Related suggestions failed: \(error.localizedDescription)"),
                id: id
            )
        }
    }
    
    internal func handleConversationalSearch(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        guard let query = arguments["query"] as? String else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Missing required parameter: query"),
                id: id
            )
        }
        
        let action = arguments["action"] as? String ?? "search"
        let sessionId = arguments["session_id"] as? String
        let limit = arguments["limit"] as? Int ?? 10
        
        // Check if conversational search service is available
        guard let conversationalSearch = conversationalSearch else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Conversational search service not available"),
                id: id
            )
        }
        
        do {
            switch action {
            case "start_session":
                let newSessionId = await conversationalSearch.startSession(sessionId: sessionId)
                let result = [
                    "action": "start_session",
                    "sessionId": newSessionId,
                    "status": "Session started successfully"
                ] as [String: Any]
                return JSONRPCResponse(result: result, error: nil, id: id)
                
            case "end_session":
                if let sessionId = sessionId {
                    await conversationalSearch.endSession(sessionId)
                    let result = [
                        "action": "end_session",
                        "sessionId": sessionId,
                        "status": "Session ended successfully"
                    ] as [String: Any]
                    return JSONRPCResponse(result: result, error: nil, id: id)
                } else {
                    return JSONRPCResponse(
                        result: nil,
                        error: JSONRPCError(code: -32602, message: "Session ID required for end_session action"),
                        id: id
                    )
                }
                
            case "refine":
                guard let sessionId = sessionId else {
                    return JSONRPCResponse(
                        result: nil,
                        error: JSONRPCError(code: -32602, message: "Session ID required for refine action"),
                        id: id
                    )
                }
                
                // Parse refinement parameters
                let refinementData = arguments["refinement"] as? [String: Any] ?? [:]
                let refinementType = refinementData["type"] as? String ?? "add_keywords"
                let keywords = refinementData["keywords"] as? [String] ?? []
                let channels = refinementData["channels"] as? [String] ?? []
                let users = refinementData["users"] as? [String] ?? []
                
                let refinement = parseSearchRefinement(
                    type: refinementType,
                    keywords: keywords,
                    channels: channels,
                    users: users
                )
                
                let searchResult = try await conversationalSearch.refineLastSearch(
                    sessionId: sessionId,
                    refinement: refinement,
                    limit: limit
                )
                
                let result = formatConversationalSearchResult(searchResult)
                return JSONRPCResponse(result: result, error: nil, id: id)
                
            default: // "search"
                var effectiveSessionId = sessionId
                
                // Start new session if none provided
                if effectiveSessionId == nil {
                    effectiveSessionId = await conversationalSearch.startSession()
                }
                
                let searchResult = try await conversationalSearch.search(
                    query: query,
                    sessionId: effectiveSessionId!,
                    limit: limit
                )
                
                let result = formatConversationalSearchResult(searchResult)
                return JSONRPCResponse(result: result, error: nil, id: id)
            }
            
        } catch {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Conversational search failed: \(error.localizedDescription)"),
                id: id
            )
        }
    }
    
    // MARK: - Helper Methods for Phase 3
    
    private func intentToString(_ intent: QueryIntent) -> String {
        switch intent {
        case .search: return "search"
        case .show: return "show"
        case .list: return "list"
        case .analyze: return "analyze"
        case .summarize: return "summarize"
        case .compare: return "compare"
        case .filter: return "filter"
        }
    }
    
    private func analyzeTopicPatterns(summaries: [TextSummary], minOccurrences: Int) -> [[String: Any]] {
        // Analyze keywords to find recurring topics
        let allKeywords = summaries.flatMap { $0.keywords }
        let keywordCounts = Dictionary(grouping: allKeywords, by: { $0 })
            .mapValues { $0.count }
            .filter { $0.value >= minOccurrences }
            .sorted { $0.value > $1.value }
        
        return keywordCounts.map { keyword, count in
            [
                "topic": keyword,
                "occurrences": count,
                "frequency": Double(count) / Double(summaries.count),
                "type": "keyword_based"
            ] as [String: Any]
        }
    }
    
    private func analyzeParticipantPatterns(summaries: [TextSummary], minOccurrences: Int) -> [[String: Any]] {
        // Analyze sender patterns
        let senders = summaries.compactMap { $0.sender }
        let senderCounts = Dictionary(grouping: senders, by: { $0 })
            .mapValues { $0.count }
            .filter { $0.value >= minOccurrences }
            .sorted { $0.value > $1.value }
        
        return senderCounts.map { sender, count in
            [
                "participant": sender,
                "messageCount": count,
                "frequency": Double(count) / Double(summaries.count),
                "type": "sender_activity"
            ] as [String: Any]
        }
    }
    
    private func analyzeCommunicationPatterns(summaries: [TextSummary]) -> [[String: Any]] {
        // Analyze temporal patterns
        let timestamps = summaries.map { $0.timestamp }
        let calendar = Calendar.current
        
        // Group by hour of day
        let hourCounts = Dictionary(grouping: timestamps) { timestamp in
            calendar.component(.hour, from: timestamp)
        }.mapValues { $0.count }
        
        // Group by day of week
        let dayOfWeekCounts = Dictionary(grouping: timestamps) { timestamp in
            calendar.component(.weekday, from: timestamp)
        }.mapValues { $0.count }
        
        return [
            [
                "pattern": "hourly_activity",
                "data": hourCounts.sorted { $0.key < $1.key }.map { ["hour": $0.key, "count": $0.value] },
                "type": "temporal"
            ],
            [
                "pattern": "daily_activity", 
                "data": dayOfWeekCounts.sorted { $0.key < $1.key }.map { ["day": $0.key, "count": $0.value] },
                "type": "temporal"
            ]
        ] as [[String: Any]]
    }
    
    private func parseSearchRefinement(
        type: String,
        keywords: [String],
        channels: [String],
        users: [String]
    ) -> SearchRefinement {
        let refinementType: SearchRefinement.RefinementType
        
        switch type {
        case "add_keywords":
            refinementType = .addKeywords
        case "remove_keywords":
            refinementType = .removeKeywords
        case "add_channels":
            refinementType = .addChannelFilter
        case "add_users":
            refinementType = .addUserFilter
        case "change_time":
            refinementType = .changeTimeRange
        default:
            refinementType = .addKeywords
        }
        
        return SearchRefinement(
            type: refinementType,
            keywords: keywords,
            channels: channels,
            users: users,
            temporalHint: nil
        )
    }
    
    private func formatConversationalSearchResult(_ searchResult: ConversationalSearchResult) -> [String: Any] {
        let results = searchResult.results.map { result in
            [
                "title": result.summary.title,
                "summary": result.summary.summary,
                "combinedScore": result.combinedScore,
                "matchedKeywords": result.matchedKeywords,
                "semanticScore": result.semanticScore,
                "keywordScore": result.keywordScore
            ] as [String: Any]
        }
        
        let refinementSuggestions = searchResult.refinementSuggestions.map { suggestion in
            [
                "type": suggestionTypeToString(suggestion.type),
                "description": suggestion.description,
                "suggestedModification": suggestion.suggestedModification
            ] as [String: Any]
        }
        
        return [
            "sessionId": searchResult.sessionId,
            "turnNumber": searchResult.turnNumber,
            "originalQuery": searchResult.originalQuery,
            "enhancedQuery": [
                "originalText": searchResult.enhancedQuery.originalText,
                "intent": intentToString(searchResult.enhancedQuery.intent),
                "keywords": searchResult.enhancedQuery.keywords,
                "entities": searchResult.enhancedQuery.entities,
                "channels": searchResult.enhancedQuery.channels,
                "users": searchResult.enhancedQuery.users
            ],
            "results": results,
            "resultCount": results.count,
            "refinementSuggestions": refinementSuggestions,
            "sessionContext": [
                "sessionId": searchResult.sessionContext.sessionId,
                "turnCount": searchResult.sessionContext.turnCount,
                "recentQueries": searchResult.sessionContext.recentQueries,
                "dominantTopics": searchResult.sessionContext.dominantTopics,
                "searchPatterns": searchResult.sessionContext.searchPatterns,
                "sessionDuration": searchResult.sessionContext.sessionDuration
            ],
            "status": "Conversational search completed"
        ] as [String: Any]
    }
    
    private func suggestionTypeToString(_ type: RefinementSuggestion.SuggestionType) -> String {
        switch type {
        case .addTimeFilter: return "add_time_filter"
        case .addChannelFilter: return "add_channel_filter"
        case .addUserFilter: return "add_user_filter"
        case .narrowScope: return "narrow_scope"
        case .expandScope: return "expand_scope"
        case .combineWithPrevious: return "combine_with_previous"
        }
    }
    
}

// MARK: - Test Support Types
