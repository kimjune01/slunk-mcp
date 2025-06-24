//
//  ContentView.swift
//  slunk-swift
//
//  Created by June Kim on 2025-06-24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var serverManager = ServerManager()
    
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
        }
        .padding()
        .frame(width: 600, height: 600)
    }
}

#Preview {
    ContentView()
}
