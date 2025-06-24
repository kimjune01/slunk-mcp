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
    
    init() {
        setupHandlers()
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
                "name": "createNote",
                "description": "Create a new note",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string", "description": "Note title"],
                        "content": ["type": "string", "description": "Note content"]
                    ],
                    "required": ["title", "content"]
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
        case "swiftVersion":
            let version = MCPServer.swiftVersion() ?? "Unknown"
            return JSONRPCResponse(
                result: ["content": [["type": "text", "text": version]]],
                error: nil,
                id: request.id
            )
            
        case "createNote":
            guard let title = arguments["title"] as? String,
                  let _ = arguments["content"] as? String else {
                return JSONRPCResponse(
                    result: nil,
                    error: JSONRPCError(code: -32602, message: "Missing required parameters"),
                    id: request.id
                )
            }
            
            // Simulate creating a note
            let noteId = UUID().uuidString
            return JSONRPCResponse(
                result: ["content": [["type": "text", "text": "Created note '\(title)' with ID: \(noteId)"]]],
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
