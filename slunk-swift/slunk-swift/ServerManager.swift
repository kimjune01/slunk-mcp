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
        
        // Initialize vector database and connect to MCP server
        Task {
            do {
                let productionService = await ProductionService.shared
                try await productionService.initialize()
                
                // Database initialized (SlackDatabaseSchema for Slack monitoring)
                if let database = await productionService.getDatabase() {
                    await MainActor.run {
                        addLog("✅ Slack database initialized")
                        addLog("✅ MCP tools use SlackQueryService directly")
                    }
                } else {
                    await MainActor.run {
                        addLog("⚠️ Could not retrieve database from production service")
                    }
                }
            } catch {
                await MainActor.run {
                    addLog("⚠️ Vector database initialization failed: \(error)")
                }
            }
        }
        
        // Don't start MCP server in GUI mode - it runs separately with --mcp flag
        // mcpServer?.start()
        isRunning = true
        
        // Get the path to the current executable
        let executablePath = Bundle.main.executablePath ?? "Unknown path"
        
        // Generate MCP config JSON
        let configJSON = """
{
  "mcpServers": {
    "slunk": {
      "command": "\(executablePath)",
      "args": ["--mcp"],
      "transport": "stdio"
    }
  }
}
"""
        mcpConfig = configJSON
        
        addLog("Monitoring service initialized")
        addLog("📍 Executable path: \(executablePath)")
        addLog("💡 MCP config ready - use copy button above to configure Claude Desktop")
    }
    
    func stop() {
        guard isRunning else { return }
        
        // MCP server runs separately, nothing to stop here
        isRunning = false
        addLog("Monitoring service stopped")
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
