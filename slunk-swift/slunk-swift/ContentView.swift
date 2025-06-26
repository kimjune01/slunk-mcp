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
    
    var buildConfiguration: String {
        #if DEBUG
        return "DEBUG"
        #else
        return "RELEASE"
        #endif
    }
    
    var buildConfigurationColor: Color {
        #if DEBUG
        return .orange
        #else
        return .green
        #endif
    }
    
    var buildTimestamp: String {
        // Get the modification date of the main executable
        if let executableURL = Bundle.main.executableURL {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: executableURL.path)
                if let modificationDate = attributes[.modificationDate] as? Date {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    formatter.timeZone = TimeZone.current
                    return formatter.string(from: modificationDate)
                }
            } catch {
                ErrorLogger.shared.log(error, context: "ContentView.buildTimestamp")
            }
        }
        return "Unknown"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                HeaderCard(
                    isRunning: serverManager.isRunning,
                    buildConfig: buildConfiguration,
                    buildTimestamp: buildTimestamp,
                    buildConfigColor: buildConfigurationColor,
                    onQuit: { showingQuitConfirmation = true }
                )
                
                // MCP Configuration Card
                if serverManager.isRunning && !serverManager.mcpConfig.isEmpty {
                    MCPConfigCard(
                        config: serverManager.mcpConfig,
                        onCopy: { serverManager.copyMCPConfig() }
                    )
                }
                
                // Database Stats Card
                DatabaseStatsCard(
                    stats: databaseStats,
                    onRefresh: { refreshDatabaseStats() }
                )
            }
            .padding(20)
        }
        .frame(minWidth: 480, minHeight: 400)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            refreshDatabaseStats()
        }
        .alert("Quit Application?", isPresented: $showingQuitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        } message: {
            Text("Are you sure you want to quit Slunk? This will stop monitoring Slack messages.")
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
                ErrorLogger.shared.log(error, context: "ContentView.refreshDatabaseStats")
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

// MARK: - Card Components

struct HeaderCard: View {
    let isRunning: Bool
    let buildConfig: String
    let buildTimestamp: String
    let buildConfigColor: Color
    let onQuit: () -> Void
    
    var body: some View {
        CardContainer {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        Text("Slunk Monitor")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 8) {
                        BuildBadge(config: buildConfig, color: buildConfigColor)
                        
                        Text("Built: \(buildTimestamp)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    StatusIndicator(isRunning: isRunning)
                    
                    Button(action: onQuit) {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                            Text("Quit")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Exit application")
                }
            }
        }
    }
}


struct MCPConfigCard: View {
    let config: String
    let onCopy: () -> Void
    
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.purple)
                        .font(.title2)
                    
                    Text("MCP Server Configuration")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button(action: onCopy) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                ScrollView {
                    Text(config)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                .frame(maxHeight: 120)
            }
        }
    }
}

struct DatabaseStatsCard: View {
    let stats: DatabaseStats?
    let onRefresh: () -> Void
    
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "cylinder.fill")
                        .foregroundColor(.teal)
                        .font(.title2)
                    
                    Text("Database Statistics")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button(action: onRefresh) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.teal.opacity(0.1))
                        .foregroundColor(.teal)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                if let stats = stats {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(
                            icon: "message.fill",
                            title: "Messages",
                            value: "\(stats.messageCount.formatted())",
                            color: .blue
                        )
                        
                        StatCard(
                            icon: "building.2.fill",
                            title: "Workspaces",
                            value: "\(stats.workspaceCount)",
                            color: .green
                        )
                        
                        StatCard(
                            icon: "externaldrive.fill",
                            title: "Database Size",
                            value: stats.databaseSize,
                            color: .orange
                        )
                    }
                    
                    HStack {
                        Text("Last updated: \(formatTimestamp(stats.lastUpdated))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading database statistics...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
            }
        }
    }
}

// MARK: - Helper Components

struct CardContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct BuildBadge: View {
    let config: String
    let color: Color
    
    var body: some View {
        Text(config)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
    }
}

struct StatusIndicator: View {
    let isRunning: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isRunning ? Color.green : Color.red)
                .frame(width: 10, height: 10)
                .shadow(color: isRunning ? .green : .red, radius: 2)
            
            Text(isRunning ? "Active" : "Inactive")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isRunning ? .green : .red)
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
}

// MARK: - Helper Extensions

private func formatTimestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: date)
}

#Preview {
    ContentView()
}
