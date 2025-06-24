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
    
    init() {
        setupHandlers()
        setupVectorComponents()
    }
    
    private func setupVectorComponents() {
        self.queryEngine = NaturalLanguageQueryEngine()
        self.smartIngestion = SmartIngestionService()
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
            
        case "getConversationStats":
            return await handleGetConversationStats(MCPRequest(method: name, params: arguments))
            
        case "swiftVersion":
            let version = MCPServer.swiftVersion() ?? "Unknown"
            return JSONRPCResponse(
                result: ["content": [["type": "text", "text": version]]],
                error: nil,
                id: request.id
            )
            
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
    
    func handleGetConversationStats(_ request: MCPRequest) async -> JSONRPCResponse {
        guard let database = database else {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Database not available"),
                id: JSONRPCId.string(request.id)
            )
        }
        
        let timeRange = request.params["timeRange"] as? String ?? "all"
        
        do {
            let stats = try await generateConversationStats(database: database, timeRange: timeRange)
            
            return JSONRPCResponse(
                result: stats,
                error: nil,
                id: JSONRPCId.string(request.id)
            )
            
        } catch {
            return JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: -32603, message: "Stats generation failed: \(error.localizedDescription)"),
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
