//
//  slunk_swiftApp.swift
//  slunk-swift
//
//  Created by June Kim on 2025-06-24.
//

import SwiftUI

@main
struct slunk_swiftApp: App {
    let mcpServer = MCPServer()
    init() {
        
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    mcpServer.start()
                }
        }
    }
}
