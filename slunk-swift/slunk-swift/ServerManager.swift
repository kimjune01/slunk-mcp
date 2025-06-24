import Foundation
import Combine
import AppKit

class ServerManager: ObservableObject {
    @Published var isRunning = false
    @Published var logs: [String] = []
    @Published var mcpConfig: String = ""
    
    private var mcpServer: MCPServer?
    private let maxLogs = 100
    
    init() {
        mcpServer = MCPServer()
    }
    
    func start() {
        guard !isRunning else { return }
        
        mcpServer?.start()
        isRunning = true
        
        // Get the path to the current executable
        let executablePath = Bundle.main.executablePath ?? "Unknown path"
        
        // Generate MCP config JSON
        let configJSON = """
{
  "mcpServers": {
    "slunk": {
      "command": "\(executablePath)",
      "args": [],
      "transport": "stdio"
    }
  }
}
"""
        mcpConfig = configJSON
        
        addLog("Server started (stdio transport)")
        addLog("📍 Executable path: \(executablePath)")
        addLog("💡 MCP config ready - use copy button above")
        
        // Simulate some initial activity
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                addLog("Waiting for JSON-RPC messages on stdin...")
            }
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        mcpServer?.stop()
        isRunning = false
        addLog("Server stopped")
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        
        logs.append(logEntry)
        
        // Keep only the last N logs
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }
    
    func copyMCPConfig() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(mcpConfig, forType: .string)
        addLog("📋 MCP config copied to clipboard!")
    }
}
