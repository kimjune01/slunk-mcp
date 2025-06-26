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
    private static let pollIntervalActive: TimeInterval = 1.0
    private static let pollIntervalBackground: TimeInterval = 5.0
    private static let pollIntervalInactive: TimeInterval = 10.0
    private static let retryDelay: TimeInterval = 5.0
    private static let maxRetries = 3
    
    // MARK: - State
    private var isMonitoring = false
    private var monitoringTask: Task<Void, Never>?
    private var currentRetryCount = 0
    private var contentParsingEnabled = false
    private var backgroundMonitoringEnabled = true
    private var lastMonitoringState: MonitoringState?
    private var currentPollInterval: TimeInterval = pollIntervalActive
    
    // MARK: - Components
    private let appObserver = SlackAppObserver()
    private let accessibilityManager = AccessibilityManager.shared
    private let slackParser = SlackUIParser.shared
    private let vectorService = ProductionService.shared
    private let cleanupService = DatabaseCleanupService.shared
    
    // MARK: - Public Interface
    
    private init() {}
    
    /// Start monitoring Slack application
    public func startMonitoring() async {
        guard !isMonitoring else {
            print("⚠️ Slack monitoring already started")
            return
        }
        
        print("ℹ️ Starting Slack monitoring service")
        
        // Initialize vector database service
        do {
            try await vectorService.initialize()
            print("✅ Vector database initialized for Slack ingestion")
            
            // Initialize cleanup service for Slack database management
            if let database = vectorService.getDatabase() as? SlackDatabaseSchema {
                cleanupService.setDatabase(database)
                cleanupService.startPeriodicCleanup()
                print("✅ Database cleanup service started (2-month retention)")
            }
        } catch {
            print("⚠️ Vector database initialization failed: \(error)")
            print("   Monitoring will continue but data won't be persisted")
        }
        
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
        
        // Load saved state
        loadMonitoringState()
        
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
        saveMonitoringState()
        
        // Stop cleanup service
        cleanupService.stopPeriodicCleanup()
        print("✅ Database cleanup service stopped")
        
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
            contentParsingEnabled: contentParsingEnabled,
            cleanupEnabled: cleanupService.cleanupEnabled,
            lastCleanupDate: cleanupService.lastCleanupDate,
            retentionPeriod: cleanupService.getRetentionDescription()
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
    
    /// Enable or disable background monitoring
    public func setBackgroundMonitoringEnabled(_ enabled: Bool) {
        backgroundMonitoringEnabled = enabled
        print("Background monitoring \(enabled ? "enabled" : "disabled")")
        saveMonitoringState()
    }
    
    /// Get current background monitoring status
    public var isBackgroundMonitoringEnabled: Bool {
        return backgroundMonitoringEnabled
    }
    
    /// Save monitoring state for persistence
    private func saveMonitoringState() {
        let state = MonitoringState(
            isMonitoring: isMonitoring,
            backgroundMonitoringEnabled: backgroundMonitoringEnabled,
            contentParsingEnabled: contentParsingEnabled,
            lastExtractedTimestamp: lastExtractedConversation?.messages.last?.timestamp,
            extractionHistoryCount: extractionHistory.count
        )
        
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: "SlunkMonitoringState")
        }
    }
    
    /// Load monitoring state from persistence
    private func loadMonitoringState() {
        guard let data = UserDefaults.standard.data(forKey: "SlunkMonitoringState"),
              let state = try? JSONDecoder().decode(MonitoringState.self, from: data) else {
            return
        }
        
        backgroundMonitoringEnabled = state.backgroundMonitoringEnabled
        contentParsingEnabled = state.contentParsingEnabled
        lastMonitoringState = state
        
        print("💾 Loaded monitoring state:")
        print("   Background monitoring: \(state.backgroundMonitoringEnabled)")
        print("   Content parsing: \(state.contentParsingEnabled)")
        print("   Last extraction: \(state.lastExtractedTimestamp?.description ?? "none")")
    }
    
    // MARK: - Private Implementation
    
    private func monitorSlackActivity() async {
        print("ℹ️ Starting monitoring loop")
        
        while isMonitoring && !Task.isCancelled {
            do {
                await processMonitoringCycle()
                try await Task.sleep(for: .seconds(currentPollInterval))
                
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
                currentPollInterval = Self.pollIntervalActive // Use fast polling when active
                
                // Phase 3: Content parsing when Slack is active
                if contentParsingEnabled {
                    await attemptContentExtraction(from: slackState)
                } else {
                    print("   ℹ️ Content parsing disabled (accessibility permissions needed)")
                }
            } else {
                // Slack is running but not in focus
                if backgroundMonitoringEnabled {
                    print("🟡 Slack is running but not in focus - continuing background monitoring")
                    currentPollInterval = Self.pollIntervalBackground
                    
                    // Still attempt content extraction in background mode
                    if contentParsingEnabled {
                        await attemptContentExtraction(from: slackState)
                    }
                } else {
                    print("⏸️ Slack not in focus - background monitoring disabled")
                    currentPollInterval = Self.pollIntervalInactive
                }
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
                timeout: 30.0 // Increased timeout for sandbox compatibility
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
            
            // Log successful content extraction
            print("   🎯 UI UPDATE: Sending \(conversation.messages.count) messages to UI")
            
            // Save state after successful extraction
            self.saveMonitoringState()
            
            // Keep only last 10 extractions to avoid memory bloat
            if extractionHistory.count > 10 {
                extractionHistory.removeFirst()
            }
        }
        
        // Phase 4: Send to vector store with automatic deduplication
        await ingestConversationToVectorStore(conversation)
    }
    
    // MARK: - Vector Database Integration
    
    /// Ingest Slack conversation into vector database
    private func ingestConversationToVectorStore(_ conversation: SlackConversation) async {
        do {
            // Track ingestion session for continuity
            let sessionId = UUID().uuidString
            // Create a summary of the conversation for vector storage
            let conversationText = conversation.messages.map { message in
                "[\(message.sender)] \(message.content)"
            }.joined(separator: "\n")
            
            let title = "Slack Conversation: \(conversation.channel)"
            let summary = generateConversationSummary(conversation)
            let sender = conversation.workspace
            
            print("   🔧 Ingesting conversation to vector database...")
            print("      Title: \(title)")
            print("      Content length: \(conversationText.count) characters")
            print("      Messages: \(conversation.messages.count)")
            
            let result = try await vectorService.ingest(
                content: conversationText,
                title: title,
                summary: summary,
                sender: sender
            )
            
            print("   ✅ Successfully ingested to vector database!")
            print("      ID: \(result.summaryId)")
            print("      Keywords: \(result.extractedKeywords.joined(separator: ", "))")
            print("      Processing time: \(String(format: "%.2f", result.processingTime))s")
            
            // Log ingestion checkpoint for resume capability
            UserDefaults.standard.set(Date(), forKey: "SlunkLastIngestionTime")
            UserDefaults.standard.set(conversation.workspace, forKey: "SlunkLastIngestionWorkspace")
            UserDefaults.standard.set(conversation.channel, forKey: "SlunkLastIngestionChannel")
            
        } catch {
            print("   ❌ Vector database ingestion failed: \(error.localizedDescription)")
            print("      Error details: \(error)")
        }
    }
    
    /// Generate a concise summary of the Slack conversation
    private func generateConversationSummary(_ conversation: SlackConversation) -> String {
        let messageCount = conversation.messages.count
        let uniqueSenders = Set(conversation.messages.map { $0.sender }).count
        let channelInfo = "\(conversation.channel) (\(conversation.channelType))"
        
        // Get a sample of message content for context
        let sampleMessages = conversation.messages.prefix(3).map { message in
            let truncatedContent = String(message.content.prefix(50))
            return "[\(message.sender)] \(truncatedContent)\(message.content.count > 50 ? "..." : "")"
        }.joined(separator: "; ")
        
        return """
        Slack conversation from \(channelInfo) in \(conversation.workspace). \
        \(messageCount) messages from \(uniqueSenders) participants. \
        Sample: \(sampleMessages)
        """
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
    
    /// Check if the application is running in a sandbox environment
    private func isSandboxed() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["APP_SANDBOX_CONTAINER_ID"] != nil
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
    public let cleanupEnabled: Bool
    public let lastCleanupDate: Date?
    public let retentionPeriod: String
    public let timestamp: Date
    
    public init(
        isMonitoring: Bool,
        slackRunning: Bool,
        slackActive: Bool,
        slackPID: pid_t,
        slackName: String,
        retryCount: Int,
        contentParsingEnabled: Bool = false,
        cleanupEnabled: Bool = true,
        lastCleanupDate: Date? = nil,
        retentionPeriod: String = "2 months"
    ) {
        self.isMonitoring = isMonitoring
        self.slackRunning = slackRunning
        self.slackActive = slackActive
        self.slackPID = slackPID
        self.slackName = slackName
        self.retryCount = retryCount
        self.contentParsingEnabled = contentParsingEnabled
        self.cleanupEnabled = cleanupEnabled
        self.lastCleanupDate = lastCleanupDate
        self.retentionPeriod = retentionPeriod
        self.timestamp = Date()
    }
    
    public var description: String {
        let cleanupDateStr = lastCleanupDate?.formatted() ?? "Never"
        return """
        Slack Monitoring Status:
        - Monitoring: \(isMonitoring ? "Active" : "Inactive")
        - Slack Running: \(slackRunning ? "Yes" : "No")
        - Slack Active: \(slackActive ? "Yes" : "No")
        - Content Parsing: \(contentParsingEnabled ? "Enabled" : "Disabled")
        - Database Cleanup: \(cleanupEnabled ? "Enabled" : "Disabled")
        - Retention Period: \(retentionPeriod)
        - Last Cleanup: \(cleanupDateStr)
        - PID: \(slackPID)
        - App Name: \(slackName)
        - Retry Count: \(retryCount)
        - Last Updated: \(timestamp)
        """
    }
}

// MARK: - Monitoring State Persistence

struct MonitoringState: Codable {
    let isMonitoring: Bool
    let backgroundMonitoringEnabled: Bool
    let contentParsingEnabled: Bool
    let lastExtractedTimestamp: Date?
    let extractionHistoryCount: Int
    let savedAt: Date = Date()
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


