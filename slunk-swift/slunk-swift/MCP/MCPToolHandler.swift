import Foundation

// MARK: - Tool Handler Protocol

protocol MCPToolHandler {
    func handle(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse
    var supportedTools: [String] { get }
}

// MARK: - Base Tool Handler

class BaseMCPToolHandler: MCPToolHandler {
    var supportedTools: [String] = []
    
    func handle(_ arguments: [String: Any], id: JSONRPCId) async -> JSONRPCResponse {
        fatalError("Subclasses must implement handle method")
    }
    
    // MARK: - Utility Methods
    
    internal func createError(code: Int, message: String, suggestions: [String] = [], id: JSONRPCId) -> JSONRPCResponse {
        var fullMessage = message
        if !suggestions.isEmpty {
            fullMessage += "\n💡 Try: " + suggestions.joined(separator: " | ")
        }
        return JSONRPCResponse(
            result: nil,
            error: JSONRPCError(code: code, message: fullMessage),
            id: id
        )
    }
    
    internal func createEmptyResultsGuidance(query: String) -> [String: Any] {
        return [
            "results": [],
            "resultCount": 0,
            "query": query,
            "guidance": "No results found. Try: broader keywords | longer time range | 'discover_patterns' to see what's available"
        ]
    }
    
    internal func logError(_ message: String) {
        #if DEBUG
        let errorHandle = FileHandle.standardError
        errorHandle.write("[MCP Tool Handler] \(message)\n".data(using: .utf8)!)
        fflush(stderr)
        #endif
    }
    
    internal func extractStringParameter(_ key: String, from arguments: [String: Any], required: Bool = true) -> String? {
        guard let value = arguments[key] as? String else {
            if required {
                logError("Missing required parameter: \(key)")
            }
            return nil
        }
        return value
    }
    
    internal func extractIntParameter(_ key: String, from arguments: [String: Any], defaultValue: Int? = nil) -> Int? {
        if let value = arguments[key] as? Int {
            return value
        }
        return defaultValue
    }
    
    internal func extractBoolParameter(_ key: String, from arguments: [String: Any], defaultValue: Bool = false) -> Bool {
        return arguments[key] as? Bool ?? defaultValue
    }
}