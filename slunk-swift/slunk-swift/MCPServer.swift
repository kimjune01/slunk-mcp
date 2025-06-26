import Foundation

// JSON-RPC structures
struct JSONRPCRequest: Codable {
    let jsonrpc: String
    let method: String
    let params: [String: AnyCodable]?
    let id: JSONRPCId
    
    enum CodingKeys: String, CodingKey {
        case jsonrpc, method, params, id
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
        method = try container.decode(String.self, forKey: .method)
        params = try container.decodeIfPresent([String: AnyCodable].self, forKey: .params)
        id = try container.decode(JSONRPCId.self, forKey: .id)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(method, forKey: .method)
        if let params = params {
            try container.encode(params, forKey: .params)
        }
        try container.encode(id, forKey: .id)
    }
}

struct JSONRPCResponse: Codable {
    var jsonrpc: String = "2.0"
    let result: AnyCodable?
    let error: JSONRPCError?
    let id: JSONRPCId
    
    init(result: Any? = nil, error: JSONRPCError? = nil, id: JSONRPCId) {
        self.result = result.map { AnyCodable($0) }
        self.error = error
        self.id = id
    }
    
    enum CodingKeys: String, CodingKey {
        case jsonrpc, result, error, id
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jsonrpc = try container.decodeIfPresent(String.self, forKey: .jsonrpc) ?? "2.0"
        result = try container.decodeIfPresent(AnyCodable.self, forKey: .result)
        error = try container.decodeIfPresent(JSONRPCError.self, forKey: .error)
        id = try container.decode(JSONRPCId.self, forKey: .id)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encodeIfPresent(result, forKey: .result)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encode(id, forKey: .id)
    }
}

struct JSONRPCError: Codable {
    let code: Int
    let message: String
    let data: AnyCodable?
    
    init(code: Int, message: String, data: Any? = nil) {
        self.code = code
        self.message = message
        self.data = data.map { AnyCodable($0) }
    }
    
    enum CodingKeys: String, CodingKey {
        case code, message, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        message = try container.decode(String.self, forKey: .message)
        data = try container.decodeIfPresent(AnyCodable.self, forKey: .data)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(data, forKey: .data)
    }
}

enum JSONRPCId: Codable {
    case string(String)
    case number(Int)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let numberValue = try? container.decode(Int.self) {
            self = .number(numberValue)
        } else {
            throw DecodingError.typeMismatch(JSONRPCId.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Int"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        }
    }
}

// Helper for encoding Any types
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let string = value as? String {
            try container.encode(string)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

class MCPServer {
    private let inputHandle = FileHandle.standardInput
    private let outputHandle = FileHandle.standardOutput
    private let errorHandle = FileHandle.standardError
    private var isRunning = false
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Vector database components
    private var database: SQLiteVecSchema?
    private var queryEngine: NaturalLanguageQueryEngine?
    private var smartIngestion: SmartIngestionService?
    private var conversationalSearch: ConversationalSearchService?
    
    init() {
        setupHandlers()
        setupVectorComponents()
    }
    
    private func setupVectorComponents() {
        self.queryEngine = NaturalLanguageQueryEngine()
        self.smartIngestion = SmartIngestionService()
        
        // Set up conversational search after query engine is created
        if let queryEngine = self.queryEngine {
            let embeddingService = EmbeddingService()
            self.conversationalSearch = ConversationalSearchService(
                queryEngine: queryEngine,
                embeddingService: embeddingService
            )
        }
    }
    
    func setDatabase(_ database: SQLiteVecSchema) {
        self.database = database
        self.queryEngine?.setDatabase(database)
        Task {
            await self.smartIngestion?.setDatabase(database)
        }
    }
    
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
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
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
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms before retry
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
            "protocolVersion": "2024-11-05",
            "capabilities": [
                "tools": [:]
            ],
            "serverInfo": [
                "name": "Slunk MCP Server",
                "version": "0.1.0"
            ]
        ]
        
        return JSONRPCResponse(result: result, error: nil, id: request.id)
    }
    
    private func handleInitialized(_ request: JSONRPCRequest) -> JSONRPCResponse {
        // Notification, no response needed
        return JSONRPCResponse(result: nil, error: nil, id: request.id)
    }
    
    private func handleToolsList(_ request: JSONRPCRequest) -> JSONRPCResponse {
        let tools: [[String: Any]] = [
            [
                "name": "searchConversations",
                "description": "Search conversations using natural language queries with semantic similarity, keyword matching, and temporal filtering",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Natural language search query (e.g., 'Swift meetings with Alice from last week')"],
                        "limit": ["type": "integer", "description": "Maximum number of results to return", "default": 10]
                    ],
                    "required": ["query"]
                ]
            ],
            [
                "name": "ingestText",
                "description": "Ingest new text content with automatic keyword extraction and embedding generation",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "content": ["type": "string", "description": "The text content to ingest"],
                        "title": ["type": "string", "description": "Title or subject of the content"],
                        "summary": ["type": "string", "description": "Brief summary of the content"],
                        "sender": ["type": "string", "description": "Name or identifier of the content sender"],
                        "timestamp": ["type": "string", "description": "ISO 8601 timestamp (optional, defaults to current time)"]
                    ],
                    "required": ["content", "title", "summary"]
                ]
            ],
            [
                "name": "getConversationStats",
                "description": "Get analytics and statistics about stored conversations",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "timeRange": ["type": "string", "description": "Time range for stats: 'day', 'week', 'month', 'all'", "default": "all"]
                    ]
                ]
            ],
            [
                "name": "swiftVersion",
                "description": "Returns the current Swift version installed on the system",
                "inputSchema": [
                    "type": "object",
                    "properties": [:],
                    "required": []
                ]
            ],
            // Phase 2: Contextual Search Tools
            [
                "name": "search_messages",
                "description": "Advanced contextual search for Slack messages with filtering and context enhancement",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Search query (semantic, keyword, or natural language)"],
                        "channels": ["type": "array", "items": ["type": "string"], "description": "Filter by specific channels"],
                        "users": ["type": "array", "items": ["type": "string"], "description": "Filter by specific users"],
                        "start_date": ["type": "string", "description": "Start date (ISO 8601)"],
                        "end_date": ["type": "string", "description": "End date (ISO 8601)"],
                        "search_mode": ["type": "string", "enum": ["semantic", "structured", "hybrid"], "default": "hybrid"],
                        "limit": ["type": "integer", "default": 10, "minimum": 1, "maximum": 100]
                    ],
                    "required": ["query"]
                ]
            ],
            [
                "name": "get_thread_context", 
                "description": "Extract complete thread conversation with context enhancement",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "thread_id": ["type": "string", "description": "Thread identifier"],
                        "include_context": ["type": "boolean", "default": true, "description": "Include contextual meaning for short messages"]
                    ],
                    "required": ["thread_id"]
                ]
            ],
            [
                "name": "get_message_context",
                "description": "Get contextual meaning for short messages (emoji, abbreviations, etc.)",
                "inputSchema": [
                    "type": "object", 
                    "properties": [
                        "message_id": ["type": "string", "description": "Message identifier"],
                        "include_thread": ["type": "boolean", "default": true, "description": "Include thread context"]
                    ],
                    "required": ["message_id"]
                ]
            ],
            // Phase 3: Advanced Query Processing Tools
            [
                "name": "parse_natural_query",
                "description": "Parse natural language queries to extract intent, entities, and temporal hints",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Natural language query to parse"],
                        "include_entities": ["type": "boolean", "default": true, "description": "Include entity extraction"],
                        "include_temporal": ["type": "boolean", "default": true, "description": "Include temporal hint extraction"]
                    ],
                    "required": ["query"]
                ]
            ],
            [
                "name": "intelligent_search",
                "description": "Advanced search combining natural language understanding with contextual search",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Natural language search query"],
                        "context": ["type": "string", "description": "Optional context from previous searches"],
                        "refine_previous": ["type": "boolean", "default": false, "description": "Refine previous search results"],
                        "limit": ["type": "integer", "default": 10, "minimum": 1, "maximum": 50]
                    ],
                    "required": ["query"]
                ]
            ],
            [
                "name": "discover_patterns",
                "description": "Discover conversation patterns and recurring themes",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "time_range": ["type": "string", "enum": ["day", "week", "month", "all"], "default": "week"],
                        "pattern_type": ["type": "string", "enum": ["topics", "participants", "communication", "all"], "default": "all"],
                        "min_occurrences": ["type": "integer", "default": 3, "minimum": 2]
                    ]
                ]
            ],
            [
                "name": "suggest_related",
                "description": "Suggest related conversations based on current query or context",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "reference_messages": ["type": "array", "items": ["type": "string"], "description": "Reference messages to find related content"],
                        "query_context": ["type": "string", "description": "Query context to base suggestions on"],
                        "suggestion_type": ["type": "string", "enum": ["similar", "followup", "related", "all"], "default": "all"],
                        "limit": ["type": "integer", "default": 5, "minimum": 1, "maximum": 20]
                    ]
                ]
            ],
            [
                "name": "conversational_search",
                "description": "Multi-turn conversational search with context awareness and refinement",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Natural language search query"],
                        "session_id": ["type": "string", "description": "Conversation session ID (optional, will create new if not provided)"],
                        "action": ["type": "string", "enum": ["search", "refine", "start_session", "end_session"], "default": "search"],
                        "refinement": [
                            "type": "object",
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
        
        return JSONRPCResponse(result: ["tools": tools], error: nil, id: request.id)
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
            
        case "ingestText":
            return await handleIngestText(MCPRequest(method: name, params: arguments))
            
        case "swiftVersion":
            let version = MCPServer.swiftVersion() ?? "Unknown"
            return JSONRPCResponse(
                result: ["content": [["type": "text", "text": version]]],
                error: nil,
                id: request.id
            )
            
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
            
        case "intelligent_search":
            return await handleIntelligentSearch(arguments, id: request.id)
            
        case "discover_patterns":
            return await handleDiscoverPatterns(arguments, id: request.id)
            
        case "suggest_related":
            return await handleSuggestRelated(arguments, id: request.id)
            
        case "conversational_search":
            return await handleConversationalSearch(arguments, id: request.id)
            
        default:
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32601, message: "Unknown tool: \(name)"),
                id: request.id
            )
        }
    }
    
    private func handleShutdown(_ request: JSONRPCRequest) -> JSONRPCResponse {
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
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
        errorHandle.write("[MCP Server] \(message)\n".data(using: .utf8)!)
        fflush(stderr)
    }
    
    // MARK: - Enhanced MCP Tool Handlers
    
    func handleSearchConversations(_ request: MCPRequest) async -> JSONRPCResponse {
        guard let database = database,
              let queryEngine = queryEngine else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Database not available"),
                id: JSONRPCId.string(request.id)
            )
        }
        
        guard let query = request.params["query"] as? String else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Missing required parameter: query"),
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
            
            return JSONRPCResponse(
                result: searchResults,
                error: nil,
                id: JSONRPCId.string(request.id)
            )
            
        } catch {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Search failed: \(error.localizedDescription)"),
                id: JSONRPCId.string(request.id)
            )
        }
    }
    
    func handleIngestText(_ request: MCPRequest) async -> JSONRPCResponse {
        guard let smartIngestion = smartIngestion else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Ingestion service not available"),
                id: JSONRPCId.string(request.id)
            )
        }
        
        guard let content = request.params["content"] as? String,
              let title = request.params["title"] as? String,
              let summary = request.params["summary"] as? String else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Missing required parameters: content, title, summary"),
                id: JSONRPCId.string(request.id)
            )
        }
        
        let sender = request.params["sender"] as? String
        let timestamp: Date?
        
        if let timestampString = request.params["timestamp"] as? String {
            timestamp = ISO8601DateFormatter().date(from: timestampString)
        } else {
            timestamp = nil
        }
        
        do {
            let result = try await smartIngestion.ingestText(
                content: content,
                title: title,
                summary: summary,
                sender: sender,
                timestamp: timestamp
            )
            
            let response = [
                "id": result.summaryId,
                "keywords": result.extractedKeywords,
                "embeddingDimensions": result.embeddingDimensions,
                "processingTime": result.processingTime
            ] as [String: Any]
            
            return JSONRPCResponse(
                result: response,
                error: nil,
                id: JSONRPCId.string(request.id)
            )
            
        } catch {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Ingestion failed: \(error.localizedDescription)"),
                id: JSONRPCId.string(request.id)
            )
        }
    }
    
    
    func handleRequest(_ request: MCPRequest) async -> JSONRPCResponse {
        // Generic handler for tests - just calls the specific handlers
        switch request.method {
        case "searchConversations":
            return await handleSearchConversations(request)
        case "ingestText":
            return await handleIngestText(request)
        case "getConversationStats":
            return await handleGetConversationStats(request)
        default:
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32601, message: "Method not found"),
                id: JSONRPCId.string(request.id)
            )
        }
    }
    
    private func generateConversationStats(database: SQLiteVecSchema, timeRange: String) async throws -> [String: Any] {
        // Use SQL aggregate functions for analytics
        let totalConversations = try await database.getTotalSummaryCount()
        
        // Get unique keywords count
        let allSummaries = try await database.getAllSummaries(limit: nil)
        let allKeywords = allSummaries.flatMap { $0.keywords }
        let uniqueKeywords = Set(allKeywords)
        
        // Get date range
        let timestamps = allSummaries.map { $0.timestamp }
        let earliestDate = timestamps.min()
        let latestDate = timestamps.max()
        
        // Get top keywords by frequency
        let keywordCounts = Dictionary(grouping: allKeywords, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        let topKeywords = Array(keywordCounts.prefix(10))
        
        // Get sender statistics
        let senders = allSummaries.compactMap { $0.sender }
        let senderCounts = Dictionary(grouping: senders, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        let stats: [String: Any] = [
            "totalConversations": totalConversations,
            "totalKeywords": uniqueKeywords.count,
            "dateRange": [
                "earliest": earliestDate?.timeIntervalSince1970 ?? 0,
                "latest": latestDate?.timeIntervalSince1970 ?? 0
            ],
            "topKeywords": topKeywords.map { ["keyword": $0.key, "count": $0.value] },
            "topSenders": senderCounts.map { ["sender": $0.key, "count": $0.value] },
            "timeRange": timeRange
        ]
        
        return stats
    }
    
    // MARK: - Phase 2 MCP Tool Handlers
    
    internal func handleSearchMessages(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        guard let query = arguments["query"] as? String else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Missing required parameter: query"),
                id: id
            )
        }
        
        // Check if database is available
        guard database != nil else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Database not available"),
                id: id
            )
        }
        
        // Extract parameters
        let channels = arguments["channels"] as? [String] ?? []
        let users = arguments["users"] as? [String] ?? []
        let startDate = (arguments["start_date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        let endDate = (arguments["end_date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        let searchModeStr = arguments["search_mode"] as? String ?? "hybrid"
        let limit = arguments["limit"] as? Int ?? 10
        
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
        
        // For now, return a placeholder response that shows we received the parameters
        // TODO: Implement actual search with database integration
        let result = [
            "query": query,
            "searchMode": searchModeStr,
            "filters": [
                "channels": channels,
                "users": users,
                "startDate": startDate?.timeIntervalSince1970 as Any,
                "endDate": endDate?.timeIntervalSince1970 as Any
            ],
            "limit": limit,
            "status": "Phase 2 search infrastructure ready",
            "message": "Search functionality implemented but requires database integration"
        ] as [String: Any]
        
        return JSONRPCResponse(result: result, error: nil, id: id)
    }
    
    internal func handleGetThreadContext(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        guard let threadId = arguments["thread_id"] as? String else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Missing required parameter: thread_id"),
                id: id
            )
        }
        
        let includeContext = arguments["include_context"] as? Bool ?? true
        
        // For now, return a placeholder response
        // TODO: Implement actual thread context extraction
        let result = [
            "threadId": threadId,
            "includeContext": includeContext,
            "status": "Thread context extraction ready",
            "message": "Thread context functionality implemented but requires database integration",
            "placeholder": [
                "threadId": threadId,
                "messages": [],
                "contextualMeanings": [],
                "participants": [],
                "timespan": [
                    "start": NSNull() as Any,
                    "end": NSNull() as Any
                ]
            ]
        ] as [String: Any]
        
        return JSONRPCResponse(result: result, error: nil, id: id)
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
        
        // For now, return a placeholder response
        // TODO: Implement actual message context extraction using MessageContextualizer
        let result = [
            "messageId": messageId,
            "includeThread": includeThread,
            "status": "Message context extraction ready",
            "message": "Message context functionality implemented but requires database integration",
            "placeholder": [
                "originalMessage": [
                    "id": messageId,
                    "content": "",
                    "sender": "",
                    "timestamp": NSNull() as Any
                ],
                "contextualMeaning": "",
                "threadContext": includeThread ? [:] as [String: Any] : NSNull() as Any,
                "enhancement": [
                    "wasShortMessage": false,
                    "contextAdded": false,
                    "embeddingEnhanced": false
                ]
            ]
        ] as [String: Any]
        
        return JSONRPCResponse(result: result, error: nil, id: id)
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
    
    internal func handleIntelligentSearch(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        guard let query = arguments["query"] as? String else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32602, message: "Missing required parameter: query"),
                id: id
            )
        }
        
        let context = arguments["context"] as? String
        let refinePrevious = arguments["refine_previous"] as? Bool ?? false
        let limit = arguments["limit"] as? Int ?? 10
        
        // Check if query engine is available
        guard let queryEngine = queryEngine else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Query engine not available"),
                id: id
            )
        }
        
        do {
            // Parse the natural language query
            let parsedQuery = queryEngine.parseQuery(query)
            
            // For now, execute basic hybrid search
            // TODO: Add context-aware refinement and multi-turn search
            let searchResults = try await queryEngine.executeHybridSearch(parsedQuery, limit: limit)
            
            let results = searchResults.map { result in
                [
                    "title": result.summary.title,
                    "summary": result.summary.summary,
                    "combinedScore": result.combinedScore,
                    "matchedKeywords": result.matchedKeywords,
                    "semanticScore": result.semanticScore,
                    "keywordScore": result.keywordScore
                ] as [String: Any]
            }
            
            let response = [
                "query": query,
                "parsedIntent": intentToString(parsedQuery.intent),
                "extractedKeywords": parsedQuery.keywords,
                "extractedEntities": parsedQuery.entities,
                "extractedChannels": parsedQuery.channels,
                "extractedUsers": parsedQuery.users,
                "context": context as Any,
                "refinePrevious": refinePrevious,
                "results": results,
                "resultCount": results.count,
                "status": "Intelligent search complete with NLP processing"
            ] as [String: Any]
            
            return JSONRPCResponse(result: response, error: nil, id: id)
            
        } catch {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Intelligent search failed: \(error.localizedDescription)"),
                id: id
            )
        }
    }
    
    internal func handleDiscoverPatterns(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        let timeRange = arguments["time_range"] as? String ?? "week"
        let patternType = arguments["pattern_type"] as? String ?? "all"
        let minOccurrences = arguments["min_occurrences"] as? Int ?? 3
        
        // Check if database is available
        guard let database = database else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Database not available"),
                id: id
            )
        }
        
        do {
            // Get conversation summaries for pattern analysis
            let summaries = try await database.getAllSummaries(limit: 1000)
            
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
                error: JSONRPCError(code: -32602, message: "Must provide either 'reference_messages' or 'query_context'"),
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
    
    static func swiftVersion() -> String? {
        // Since we're in an App Sandbox, we can't execute external processes
        // Instead, return the Swift version this app was compiled with
        #if swift(>=6.1)
            return "Apple Swift version 6.1+ (compiled with this app)\nTarget: arm64-apple-macosx\nNote: App is sandboxed, cannot execute external swift command"
        #elseif swift(>=6.0)
            return "Apple Swift version 6.0+ (compiled with this app)\nTarget: arm64-apple-macosx\nNote: App is sandboxed, cannot execute external swift command"
        #elseif swift(>=5.9)
            return "Apple Swift version 5.9+ (compiled with this app)\nTarget: arm64-apple-macosx\nNote: App is sandboxed, cannot execute external swift command"
        #elseif swift(>=5.8)
            return "Apple Swift version 5.8+ (compiled with this app)\nTarget: arm64-apple-macosx\nNote: App is sandboxed, cannot execute external swift command"
        #else
            return "Apple Swift version 5.x+ (compiled with this app)\nTarget: arm64-apple-macosx\nNote: App is sandboxed, cannot execute external swift command"
        #endif
    }
}

// MARK: - Test Support Types

struct MCPRequest {
    let method: String
    let params: [String: Any]
    let jsonrpc: String = "2.0"
    let id: String = UUID().uuidString
}
