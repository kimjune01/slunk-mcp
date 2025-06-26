//
//  ContentView.swift
//  slunk-swift
//
//  Created by June Kim on 2025-06-24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var serverManager = ServerManager()
    @State private var databaseStats: DatabaseStats?
    @State private var showingQuitConfirmation = false
    
    var body: some View {
        VStack(spacing: 10) {
            // Header with title and exit button
            HStack {
                Text("MCP Server")
                    .font(.title2)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(serverManager.isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(serverManager.isRunning ? "Running" : "Stopped")
                        .font(.caption)
                        .foregroundColor(serverManager.isRunning ? .green : .red)
                }
                
                Spacer()
                
                Button(action: {
                    showingQuitConfirmation = true
                }) {
                    Text("QUIT")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Exit application")
            }
            .padding(.bottom, 5)
            
            
            // Only show start button when server is not running
            if !serverManager.isRunning {
                Button("Start Server") {
                    serverManager.start()
                }
                .buttonStyle(.borderedProminent)
            }
            
            if serverManager.isRunning && !serverManager.mcpConfig.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Configuration")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button("Copy Config") {
                            serverManager.copyMCPConfig()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    
                    ScrollView {
                        Text(serverManager.mcpConfig)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .frame(height: 80)
                }
            }
            
            // Database Stats Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Database Stats")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Button("Refresh") {
                        refreshDatabaseStats()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                
                if let stats = databaseStats {
                    HStack(spacing: 15) {
                        HStack(spacing: 4) {
                            Text("Messages:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(stats.messageCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Divider()
                            .frame(height: 12)
                        
                        HStack(spacing: 4) {
                            Text("Workspaces:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(stats.workspaceCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Divider()
                            .frame(height: 12)
                        
                        HStack(spacing: 4) {
                            Text("Size:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(stats.databaseSize)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Text(formatTimestamp(stats.lastUpdated))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(6)
                } else {
                    HStack {
                        Text("Loading stats...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(6)
                }
            }
            
        }
        .padding(12)
        .frame(width: 400, height: 280)
        .onAppear {
            refreshDatabaseStats()
            // Auto-start MCP server
            if !serverManager.isRunning {
                serverManager.start()
            }
        }
        .alert("Quit Application?", isPresented: $showingQuitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        } message: {
            Text("Are you sure you want to quit the MCP Server?")
        }
    }
    
    private func refreshDatabaseStats() {
        Task {
            do {
                // Add timeout to prevent hanging
                let stats = try await withTimeout(seconds: 3) {
                    try await getDatabaseStatistics()
                }
                await MainActor.run {
                    self.databaseStats = stats
                }
            } catch {
                print("Failed to get database stats: \(error)")
                // Set fallback stats on error
                await MainActor.run {
                    self.databaseStats = DatabaseStats(
                        messageCount: 0,
                        workspaceCount: 0,
                        databaseSize: "Unknown",
                        lastUpdated: Date()
                    )
                }
            }
        }
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
    
    private func getDatabaseStatistics() async throws -> DatabaseStats {
        let vectorService = ProductionService.shared
        
        // Check if service is initialized, if not return empty stats
        guard vectorService.isInitialized else {
            return DatabaseStats(
                messageCount: 0,
                workspaceCount: 0,
                databaseSize: "0 KB",
                lastUpdated: Date()
            )
        }
        
        guard let database = vectorService.getDatabase() as? SlackDatabaseSchema else {
            return DatabaseStats(
                messageCount: 0,
                workspaceCount: 0,
                databaseSize: "0 KB",
                lastUpdated: Date()
            )
        }
        
        let messageCount = try await database.getMessageCount()
        let workspaceCount = try await database.getWorkspaceCount()
        let databaseSize = try await database.getDatabaseSize()
        
        return DatabaseStats(
            messageCount: messageCount,
            workspaceCount: workspaceCount,
            databaseSize: formatBytes(databaseSize),
            lastUpdated: Date()
        )
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct DatabaseStats {
    let messageCount: Int
    let workspaceCount: Int
    let databaseSize: String
    let lastUpdated: Date
}

enum DatabaseError: Error {
    case notInitialized
}

struct TimeoutError: Error {}

#Preview {
    ContentView()
}
