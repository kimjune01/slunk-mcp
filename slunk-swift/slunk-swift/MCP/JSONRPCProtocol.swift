import Foundation

// MARK: - JSON-RPC Protocol Structures

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
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Int.self) {
            self = .number(number)
        } else {
            throw DecodingError.typeMismatch(JSONRPCId.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected string or number"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        }
    }
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let codableArray = array.map { AnyCodable($0) }
            try container.encode(codableArray)
        case let dictionary as [String: Any]:
            let codableDictionary = dictionary.mapValues { AnyCodable($0) }
            try container.encode(codableDictionary)
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

// MARK: - MCP Request Structure

struct MCPRequest {
    let method: String
    let params: [String: Any]
    let jsonrpc: String = "2.0"
    let id: String = UUID().uuidString
    
    init(method: String, params: [String: Any]) {
        self.method = method
        self.params = params
    }
}