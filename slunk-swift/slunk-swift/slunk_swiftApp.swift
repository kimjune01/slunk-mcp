import SwiftUI
import AppKit

@main
struct slunk_swiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Check if we should run as MCP server
        let args = CommandLine.arguments
        let isMCPMode = args.contains("--mcp") || ProcessInfo.processInfo.environment["MCP_MODE"] != nil
        
        if isMCPMode {
            // Run as MCP server only
            // Create a separate function to handle MCP mode
            runMCPMode()
            
            // This prevents the SwiftUI app from starting
            return
        }
    }
    
    private func runMCPMode() {
        // Initialize MCP server asynchronously
        Task {
            do {
                // Initialize the production service to set up database
                FileHandle.standardError.write("[MCP] Initializing database...\n".data(using: .utf8)!)
                let productionService = ProductionService.shared
                try await productionService.initialize()
                FileHandle.standardError.write("[MCP] Database initialized successfully\n".data(using: .utf8)!)
                
                // Create and start MCP server after database is ready
                let mcpServer = MCPServer()
                FileHandle.standardError.write("[MCP] Starting MCP server...\n".data(using: .utf8)!)
                mcpServer.start()
                
                // Use RunLoop.main.run() instead of dispatchMain()
                // This is the preferred approach for macOS applications
                // and avoids the dispatch_main restriction issues
                FileHandle.standardError.write("[MCP] Server started, entering run loop...\n".data(using: .utf8)!)
                RunLoop.main.run()
                
            } catch {
                FileHandle.standardError.write("[MCP] Failed to initialize: \(error)\n".data(using: .utf8)!)
                exit(1)
            }
        }
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the app from the dock
        NSApp.setActivationPolicy(.accessory)
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = createHashtagIcon()
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Start monitoring service only (MCP server runs separately)
        Task {
            await SlackMonitoringService.shared.startMonitoring()
        }
        
        setupMenu()
    }
    
    @objc func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                showPopover()
            }
        } else {
            showPopover()
        }
    }
    
    func showPopover() {
        if popover == nil {
            popover = NSPopover()
            popover?.contentViewController = NSHostingController(rootView: ContentView())
            popover?.behavior = .transient
        }
        
        if let button = statusItem?.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        // Monitoring status
        let statusItem = NSMenuItem(title: "Slack Monitoring: Checking...", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle monitoring
        let toggleMonitoring = NSMenuItem(title: "Toggle Monitoring", action: #selector(toggleMonitoring), keyEquivalent: "m")
        toggleMonitoring.target = self
        menu.addItem(toggleMonitoring)
        
        // Toggle background monitoring
        let toggleBackground = NSMenuItem(title: "Toggle Background Monitoring", action: #selector(toggleBackgroundMonitoring), keyEquivalent: "b")
        toggleBackground.target = self
        menu.addItem(toggleBackground)
        
        menu.addItem(NSMenuItem.separator())
        
        // Show window
        let showWindow = NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: "w")
        showWindow.target = self
        menu.addItem(showWindow)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Slunk", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        // Update menu status periodically
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak statusItem] _ in
            guard let statusItem = statusItem else { return }
            Task {
                await self.updateMenuStatus(statusItem)
            }
        }
    }
    
    @objc func toggleMonitoring() {
        Task {
            let isMonitoring = await SlackMonitoringService.shared.isMonitoring
            if isMonitoring {
                await SlackMonitoringService.shared.stopMonitoring()
            } else {
                await SlackMonitoringService.shared.startMonitoring()
            }
        }
    }
    
    @objc func toggleBackgroundMonitoring() {
        Task {
            let status = await SlackMonitoringService.shared.getStatusInfo()
            await SlackMonitoringService.shared.setBackgroundMonitoringEnabled(!status.contentParsingEnabled)
        }
    }
    
    @objc func showWindow() {
        // Create and show a regular window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Slunk - Slack Monitor"
        window.contentView = NSHostingView(rootView: ContentView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Bring app to front temporarily
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Return to accessory mode when window closes
        window.setIsVisible(true)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    func updateMenuStatus(_ menuItem: NSMenuItem) async {
        let status = await SlackMonitoringService.shared.getStatusInfo()
        
        await MainActor.run {
            if status.isMonitoring {
                if status.slackActive {
                    menuItem.title = "✅ Slack Active - Monitoring"
                } else if status.slackRunning {
                    menuItem.title = "🟡 Slack Running - Background Mode"
                } else {
                    menuItem.title = "🔍 Monitoring - Scanning for Slack"
                }
            } else {
                menuItem.title = "❌ Monitoring Stopped"
            }
        }
    }
    
    @objc func quit() {
        Task {
            await SlackMonitoringService.shared.stopMonitoring()
            await MainActor.run {
                NSApp.terminate(nil)
            }
        }
    }
    
    func createHashtagIcon() -> NSImage {
        let size = CGSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Set up the drawing context
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        // Use system tint color or default to black
        let color = NSColor.controlAccentColor.cgColor
        context.setStrokeColor(color)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        
        // Draw hashtag (#) symbol
        let margin: CGFloat = 3
        let lineSpacing: CGFloat = 6
        let lineLength: CGFloat = size.width - (2 * margin)
        
        // Horizontal lines
        context.move(to: CGPoint(x: margin, y: margin + lineSpacing))
        context.addLine(to: CGPoint(x: margin + lineLength, y: margin + lineSpacing))
        
        context.move(to: CGPoint(x: margin, y: margin + (2 * lineSpacing)))
        context.addLine(to: CGPoint(x: margin + lineLength, y: margin + (2 * lineSpacing)))
        
        // Vertical lines (slightly angled for hashtag look)
        let verticalOffset: CGFloat = 1.5
        
        context.move(to: CGPoint(x: margin + (lineLength * 0.3) - verticalOffset, y: margin))
        context.addLine(to: CGPoint(x: margin + (lineLength * 0.3) + verticalOffset, y: margin + (3 * lineSpacing)))
        
        context.move(to: CGPoint(x: margin + (lineLength * 0.7) - verticalOffset, y: margin))
        context.addLine(to: CGPoint(x: margin + (lineLength * 0.7) + verticalOffset, y: margin + (3 * lineSpacing)))
        
        context.strokePath()
        
        image.unlockFocus()
        
        // Set template rendering mode so it respects system appearance
        image.isTemplate = true
        
        return image
    }
}