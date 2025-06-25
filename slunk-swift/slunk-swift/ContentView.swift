//
//  ContentView.swift
//  slunk-swift
//
//  Created by June Kim on 2025-06-24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var serverManager = ServerManager()
    @StateObject private var slackMonitor = SlackMonitoringService.shared
    @State private var testResults: String = ""
    @State private var isRunningTests = false
    @State private var isSlackMonitoring = false
    @State private var slackStatus: String = "Not monitoring"
    @State private var contentParsingEnabled = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MCP Server (stdio)")
                .font(.largeTitle)
                .padding()
            
            HStack {
                Circle()
                    .fill(serverManager.isRunning ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(serverManager.isRunning ? "Running" : "Stopped")
                    .foregroundColor(serverManager.isRunning ? .green : .red)
            }
            
            HStack(spacing: 20) {
                Button("Start Server") {
                    serverManager.start()
                }
                .disabled(serverManager.isRunning)
                
                Button("Stop Server") {
                    serverManager.stop()
                }
                .disabled(!serverManager.isRunning)
                
                Button("🧪 Run Tests") {
                    runTests()
                }
                .disabled(isRunningTests)
                .buttonStyle(.borderedProminent)
            }
            
            // Slack Monitoring Section
            VStack(spacing: 10) {
                HStack {
                    Circle()
                        .fill(isSlackMonitoring ? Color.blue : Color.gray)
                        .frame(width: 10, height: 10)
                    Text("Slack Monitor: \(slackStatus)")
                        .foregroundColor(isSlackMonitoring ? .blue : .gray)
                }
                
                HStack(spacing: 20) {
                    Button("🔍 Start Slack Monitoring") {
                        startSlackMonitoring()
                    }
                    .disabled(isSlackMonitoring)
                    .buttonStyle(.bordered)
                    
                    Button("⏹ Stop Slack Monitoring") {
                        stopSlackMonitoring()
                    }
                    .disabled(!isSlackMonitoring)
                    .buttonStyle(.bordered)
                }
                
                // Content parsing toggle
                HStack {
                    Toggle("📋 Content Parsing", isOn: $contentParsingEnabled)
                        .disabled(!isSlackMonitoring)
                        .onChange(of: contentParsingEnabled) { newValue in
                            Task {
                                await slackMonitor.setContentParsingEnabled(newValue)
                            }
                        }
                    
                    Spacer()
                    
                    Text("Extract messages from Slack")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Extracted Content Display
            if let conversation = slackMonitor.lastExtractedConversation {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("📋 Latest Extracted Content")
                            .font(.headline)
                        Spacer()
                        Text("\(slackMonitor.extractionHistory.count) total extractions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("🗑 Clear") {
                            slackMonitor.clearExtractedContent()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Conversation Header
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Workspace:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(conversation.workspace)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("Channel:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(conversation.channel) (\(conversation.channelType))")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("Messages:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(conversation.messages.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                    
                    // Messages Display
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(conversation.messages.enumerated()), id: \.offset) { index, message in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(message.sender)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                        Spacer()
                                        Text(formatTimestamp(message.timestamp))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(message.content)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.5))
                                .cornerRadius(6)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 250)
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.top)
            }
            
            if serverManager.isRunning && !serverManager.mcpConfig.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("MCP Client Configuration:")
                            .font(.headline)
                        Spacer()
                        Button("📋 Copy Config") {
                            serverManager.copyMCPConfig()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    ScrollView {
                        Text(serverManager.mcpConfig)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .frame(height: 120)
                }
                .padding(.top)
            }
            
            if !serverManager.logs.isEmpty {
                VStack(alignment: .leading) {
                    Text("Server Logs:")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(serverManager.logs, id: \.self) { log in
                                Text(log)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.top)
            }
            
            if !testResults.isEmpty {
                VStack(alignment: .leading) {
                    Text("Test Results:")
                        .font(.headline)
                    
                    ScrollView {
                        Text(testResults)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.top)
            }
        }
        .padding()
        .frame(width: 600, height: 800)
    }
    
    private func runTests() {
        isRunningTests = true
        testResults = "Requesting accessibility permissions...\n"
        
        Task {
            let accessibilityManager = AccessibilityManager.shared
            let permissionStatus = await accessibilityManager.requestAccessibilityPermissions()
            
            await MainActor.run {
                if permissionStatus == .permissionDenied {
                    testResults = """
                    ❌ Accessibility permissions required!
                    
                    Please:
                    1. Open System Preferences (or System Settings)
                    2. Go to Privacy & Security > Accessibility
                    3. Click the lock to make changes (enter password)
                    4. Make sure this app is checked in the list
                    5. Try running tests again
                    
                    Note: If the app doesn't appear in the list, click the "+" button and add it manually.
                    """
                    isRunningTests = false
                    return
                }
                
                testResults = """
                ✅ Accessibility permissions granted. Running tests...
                
                📊 Detailed results are being logged to system logs.
                
                To view logs in real-time, run in Terminal:
                log stream --predicate 'subsystem == "com.slunk.slunk-swift"' --level info
                
                Or use Console.app and filter by: com.slunk.slunk-swift
                
                """
            }
            
            // Run the actual tests
            let detailedOutput = await TestRunner.runWithDetailedOutput()
            
            await MainActor.run {
                testResults = detailedOutput
                isRunningTests = false
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func startSlackMonitoring() {
        print("🚀 Starting Slack monitoring from UI...")
        isSlackMonitoring = true
        slackStatus = "Starting..."
        
        Task {
            await slackMonitor.startMonitoring()
            
            // Update status periodically
            while isSlackMonitoring {
                let status = await slackMonitor.getStatusInfo()
                await MainActor.run {
                    // Update content parsing toggle to match service state
                    contentParsingEnabled = status.contentParsingEnabled
                    
                    if status.slackRunning {
                        if status.slackActive {
                            if status.contentParsingEnabled {
                                slackStatus = "✅ Slack active - parsing content!"
                            } else {
                                slackStatus = "✅ Slack active - parsing disabled"
                            }
                        } else {
                            slackStatus = "🟡 Slack found but not active"
                        }
                    } else {
                        slackStatus = "🔍 Scanning for Slack..."
                    }
                }
                
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    private func stopSlackMonitoring() {
        print("⏹ Stopping Slack monitoring from UI...")
        isSlackMonitoring = false
        slackStatus = "Stopped"
        
        Task {
            await slackMonitor.stopMonitoring()
        }
    }
}

#Preview {
    ContentView()
}
