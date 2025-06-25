import Foundation
import AppKit
import OSLog

/// Main coordinator service for Slack accessibility monitoring
/// Uses sensible defaults and simple, maintainable architecture
@MainActor
public final class SlackMonitoringService: ObservableObject {
    public static let shared = SlackMonitoringService()
    
    // Published properties for UI updates
    @Published public private(set) var lastExtractedConversation: SlackConversation?
    @Published public private(set) var extractionHistory: [SlackConversation] = []
    
    // MARK: - Constants
    private static let pollInterval: TimeInterval = 1.0
    private static let retryDelay: TimeInterval = 5.0
    private static let maxRetries = 3
    
    // MARK: - State
    private var isMonitoring = false
    private var monitoringTask: Task<Void, Never>?
    private var currentRetryCount = 0
    private var contentParsingEnabled = false
    
    // MARK: - Components
    private let appObserver = SlackAppObserver()
    private let accessibilityManager = AccessibilityManager.shared
    private let slackParser = SlackUIParser.shared
    
    // MARK: - Public Interface
    
    private init() {}
    
    /// Start monitoring Slack application
    public func startMonitoring() async {
        guard !isMonitoring else {
            print("⚠️ Slack monitoring already started")
            return
        }
        
        print("ℹ️ Starting Slack monitoring service")
        
        // Check accessibility permissions first
        let accessibilityStatus = await accessibilityManager.requestAccessibilityPermissions()
        if accessibilityStatus == .permissionDenied {
            print("❌ Accessibility permissions required for content parsing")
            print("   Content parsing will be disabled until permissions are granted")
            contentParsingEnabled = false
        } else {
            print("✅ Accessibility permissions granted - content parsing enabled")
            contentParsingEnabled = true
        }
        
        isMonitoring = true
        currentRetryCount = 0
        
        monitoringTask = Task {
            await monitorSlackActivity()
        }
    }
    
    /// Stop monitoring Slack application
    public func stopMonitoring() {
        guard isMonitoring else {
            print("Slack monitoring not currently running")
            return
        }
        
        print("Stopping Slack monitoring service")
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        currentRetryCount = 0
    }
    
    /// Check if Slack monitoring is currently active
    public var isActive: Bool {
        return isMonitoring
    }
    
    /// Get current Slack app state
    public func getCurrentSlackState() async -> AppState? {
        return await appObserver.getSlackAppState()
    }
    
    /// Get service status information
    public func getStatusInfo() async -> ServiceStatus {
        let slackState = await getCurrentSlackState()
        
        return ServiceStatus(
            isMonitoring: isMonitoring,
            slackRunning: slackState != nil,
            slackActive: slackState?.isActive ?? false,
            slackPID: slackState?.pid ?? 0,
            slackName: slackState?.name ?? "N/A",
            retryCount: currentRetryCount,
            contentParsingEnabled: contentParsingEnabled
        )
    }
    
    /// Enable or disable content parsing
    public func setContentParsingEnabled(_ enabled: Bool) {
        contentParsingEnabled = enabled
        print("Content parsing \(enabled ? "enabled" : "disabled")")
    }
    
    /// Get current content parsing status
    public var isContentParsingEnabled: Bool {
        return contentParsingEnabled
    }
    
    /// Clear extracted content history
    public func clearExtractedContent() {
        lastExtractedConversation = nil
        extractionHistory.removeAll()
        print("📋 Extracted content history cleared")
    }
    
    // MARK: - Private Implementation
    
    private func monitorSlackActivity() async {
        print("ℹ️ Starting monitoring loop")
        
        while isMonitoring && !Task.isCancelled {
            do {
                await processMonitoringCycle()
                try await Task.sleep(for: .seconds(Self.pollInterval))
                
            } catch {
                await handleMonitoringError(error)
            }
        }
        
        print("ℹ️ Monitoring loop ended")
    }
    
    private func processMonitoringCycle() async {
        if let slackState = await appObserver.getSlackAppState() {
            if slackState.isActive {
                print("✅ SLACK DETECTED! Slack is active and ready for monitoring")
                print("   📊 PID: \(slackState.pid), Name: \(slackState.name)")
                currentRetryCount = 0 // Reset retry count on successful detection
                
                // Phase 3: Content parsing when Slack is active
                if contentParsingEnabled {
                    await attemptContentExtraction(from: slackState)
                } else {
                    print("   ℹ️ Content parsing disabled (accessibility permissions needed)")
                }
            } else {
                // Slack is running but not in focus - no logging needed for normal operation
            }
        } else {
            print("🔍 Scanning for Slack... (not currently running)")
        }
    }
    
    private func handleMonitoringError(_ error: Error) async {
        if error is CancellationError {
            print("ℹ️ Monitoring task cancelled")
            return
        }
        
        currentRetryCount += 1
        
        if currentRetryCount <= Self.maxRetries {
            print("⚠️ Monitoring error (retry \(currentRetryCount)/\(Self.maxRetries)): \(error.localizedDescription)")
            
            // Wait before retry
            do {
                try await Task.sleep(for: .seconds(Self.retryDelay))
            } catch {
                // Task was cancelled during retry delay
                return
            }
        } else {
            print("❌ Max retries exceeded, continuing with reduced frequency")
            currentRetryCount = 0 // Reset for next cycle
            
            // Wait longer before next attempt
            do {
                try await Task.sleep(for: .seconds(Self.retryDelay * 2))
            } catch {
                return
            }
        }
    }
    
    // MARK: - Content Extraction (Phase 3)
    
    /// Attempt to extract content from active Slack application
    private func attemptContentExtraction(from slackState: AppState) async {
        do {
            // Create LBAccessibility Element for the Slack application
            print("   🔍 Creating LBAccessibility element for PID: \(slackState.pid)")
            let slackApplication = Element(processIdentifier: slackState.pid)
            
            print("   ✅ Created LBAccessibility element, attempting content extraction...")
            
            // Debug: Check what we can see in the app element
            let appTitle = try slackApplication.getAttributeValue(.title) as? String
            let appRole = try slackApplication.getAttributeValue(.role) as? Role
            print("   📊 App element - Title: '\(appTitle ?? "nil")', Role: '\(appRole?.rawValue ?? "nil")'")
            
            // Try to parse current conversation
            if let conversation = try await slackParser.parseCurrentConversation(
                from: slackApplication,
                timeout: 10.0 // Short timeout for real-time monitoring
            ) {
                await handleExtractedContent(conversation)
            } else {
                print("   📝 No active conversation detected by parser")
            }
            
        } catch {
            print("   ⚠️ Content extraction failed: \(error.localizedDescription)")
            print("   🔍 Error details: \(error)")
        }
    }
    
    /// Handle successfully extracted Slack content
    private func handleExtractedContent(_ conversation: SlackConversation) async {
        print("   📋 CONTENT EXTRACTED!")
        print("      Workspace: \(conversation.workspace)")
        print("      Channel: \(conversation.channel) (\(conversation.channelType))")
        print("      Messages: \(conversation.messages.count)")
        
        // Show recent message info for debugging
        if let recentMessage = conversation.messages.last {
            print("      Latest: [\(recentMessage.sender)] \(String(recentMessage.content.prefix(50)))\(recentMessage.content.count > 50 ? "..." : "")")
        }
        
        // Update UI with extracted content
        await MainActor.run {
            lastExtractedConversation = conversation
            extractionHistory.append(conversation)
            
            // Keep only last 10 extractions to avoid memory bloat
            if extractionHistory.count > 10 {
                extractionHistory.removeFirst()
            }
        }
        
        // TODO Phase 4: Add deduplication logic here
        // TODO Phase 5: Send to vector store here
    }
    
    // MARK: - System Event Handling
    
    /// Handle system sleep events
    public func handleSystemSleep() {
        print("System going to sleep, monitoring will pause gracefully")
    }
    
    /// Handle system wake events
    public func handleSystemWake() {
        print("System waking up, monitoring will resume")
    }
}

// MARK: - Slack App Observer

/// Dedicated observer for Slack application state
public actor SlackAppObserver {
    
    // MARK: - Constants
    private static let slackBundleIds = [
        "com.tinyspeck.slackmacgap",  // Standard Slack
        "com.tinyspeck.slack",        // Alternative bundle ID
        "com.tinyspeck.slackforportal" // Enterprise Slack
    ]
    
    /// Get current state of Slack application
    public func getSlackAppState() async -> AppState? {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // First, try to find by bundle identifier
        for app in runningApps {
            if let bundleId = app.bundleIdentifier,
               Self.slackBundleIds.contains(bundleId) {
                return AppState(runningApplication: app)
            }
        }
        
        // Fallback: check by application name
        for app in runningApps {
            if let appName = app.localizedName,
               appName.lowercased().contains("slack") {
                print("✅ Found Slack app by name: \(appName), PID: \(app.processIdentifier)")
                return AppState(runningApplication: app)
            }
        }
        
        return nil
    }
    
    /// Check if any Slack application is currently running
    public func isSlackRunning() async -> Bool {
        return await getSlackAppState() != nil
    }
    
    /// Get all running applications (for debugging)
    public func getAllRunningApps() -> [AppState] {
        return NSWorkspace.shared.runningApplications.map { AppState(runningApplication: $0) }
    }
}

// MARK: - Service Status

public struct ServiceStatus: Codable {
    public let isMonitoring: Bool
    public let slackRunning: Bool
    public let slackActive: Bool
    public let slackPID: pid_t
    public let slackName: String
    public let retryCount: Int
    public let contentParsingEnabled: Bool
    public let timestamp: Date
    
    public init(
        isMonitoring: Bool,
        slackRunning: Bool,
        slackActive: Bool,
        slackPID: pid_t,
        slackName: String,
        retryCount: Int,
        contentParsingEnabled: Bool = false
    ) {
        self.isMonitoring = isMonitoring
        self.slackRunning = slackRunning
        self.slackActive = slackActive
        self.slackPID = slackPID
        self.slackName = slackName
        self.retryCount = retryCount
        self.contentParsingEnabled = contentParsingEnabled
        self.timestamp = Date()
    }
    
    public var description: String {
        return """
        Slack Monitoring Status:
        - Monitoring: \(isMonitoring ? "Active" : "Inactive")
        - Slack Running: \(slackRunning ? "Yes" : "No")
        - Slack Active: \(slackActive ? "Yes" : "No")
        - Content Parsing: \(contentParsingEnabled ? "Enabled" : "Disabled")
        - PID: \(slackPID)
        - App Name: \(slackName)
        - Retry Count: \(retryCount)
        - Last Updated: \(timestamp)
        """
    }
}

// MARK: - Health Check Support

extension SlackMonitoringService: HealthCheckable {
    public func healthCheck() async -> HealthStatus {
        let status = await getStatusInfo()
        
        if !isMonitoring {
            return .unhealthy("Service is not monitoring", details: [
                "isMonitoring": "false"
            ])
        }
        
        if status.retryCount > Self.maxRetries {
            return .unhealthy("Excessive retry attempts", details: [
                "retryCount": "\(status.retryCount)",
                "maxRetries": "\(Self.maxRetries)"
            ])
        }
        
        return .healthy
    }
}


