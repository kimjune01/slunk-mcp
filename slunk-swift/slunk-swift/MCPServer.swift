import Foundation
import Swifter

class MCPServer {
    private let server = HttpServer()
    
    init() {
        setupRoutes()
    }
    
    private func setupRoutes() {
        server["/metadata"] = { _ in
            let metadata: [String: Any] = [
                "name": "My macOS App MCP Server",
                "description": "Exposes app context to LLM",
                "version": "0.1"
            ]
            return .ok(.json(metadata))
        }
        
        server["/context"] = { _ in
            let context: [String: Any] = [
                "messages": [
                    ["role": "user", "content": "Hello from macOS!"],
                    ["role": "assistant", "content": "Hi there!"]
                ]
            ]
            return .ok(.json(context))
        }
        
        server["/tools"] = { _ in
            print("Received tools request")
            let tools: [[String: Any]] = [
                [
                    "name": "createNote",
                    "description": "Create a new note",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string"],
                            "content": ["type": "string"]
                        ],
                        "required": ["title", "content"]
                    ]
                ],
                [
                    "name": "swiftVersion",
                    "description": "Returns the current Swift version installed on the system",
                    "parameters": [
                        "type": "object",
                        "properties": [:],
                        "required": []
                    ]
                ]
            ]
            return .ok(.json(["tools": tools]))
        }
        
        server["/execute"] = { req in
            guard let body = try? JSONSerialization.jsonObject(with: Data(req.body), options: []) as? [String: Any] else {
                return .badRequest(nil)
            }
            print("Received execute: \(body)")
            if let name = body["name"] as? String, name == "swiftVersion" {
                let version = MCPServer.swiftVersion() ?? "Unknown"
                return .ok(.json(["result": version]))
            }
            return .ok(.json(["status": "executed"]))
        }
    }
    
    func start(port: UInt16 = 9990) {
        do {
            try server.start(port)
            print("✅ MCP server running on http://localhost:\(port)")
        } catch {
            print("❌ Failed to start server: \(error)")
        }
    }
    
    func stop() {
        server.stop()
        print("🛑 MCP server stopped")
    }
    
    static func swiftVersion() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "--version"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "Error running swift-version: \(error)"
        }
    }
}
