import Foundation
import AppKit
import OSLog

/// Main coordinator service for Slack accessibility monitoring
/// Refactored for better maintainability and separation of concerns
@MainActor
public final class SlackMonitoringService: ObservableObject {
    public static let shared = SlackMonitoringService()
    
    // MARK: - Published Properties
    @Published public private(set) var lastExtractedConversation: SlackConversation?
    @Published public private(set) var extractionHistory: [SlackConversation] = []
    @Published public private(set) var isMonitoring = false
    
    // MARK: - Configuration
    private var config = MonitoringConfiguration.default
    
    // MARK: - Services
    private let appObserver = SlackAppObserver()
    private let accessibilityManager = AccessibilityManager.shared
    private let slackParser = SlackUIParser.shared
    private let vectorService = ProductionService.shared
    private let cleanupService = DatabaseCleanupService.shared
    private let ingestionService = DatabaseIngestionService()
    
    // MARK: - Debug Logging
    private let logFileURL: URL = {
        let logsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return logsDir.appendingPathComponent("slunk_debug.log")
    }()
    
    // MARK: - State
    private var monitoringTask: Task<Void, Never>?
    private var currentRetryCount = 0
    private var currentPollInterval: TimeInterval
    
    // MARK: - Initialization
    
    private init() {
        self.currentPollInterval = config.pollIntervalActive
    }
    
    // MARK: - Logging
    
    private func logToFile(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                // Use defer to ensure FileHandle is always closed
                do {
                    let fileHandle = try FileHandle(forWritingTo: logFileURL)
                    defer { 
                        try? fileHandle.close()
                    }
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                } catch {
                    Logger.shared.logError(error, context: "SlackMonitoringService.logToFile")
                }
            } else {
                do {
                    try data.write(to: logFileURL)
                } catch {
                    Logger.shared.logError(error, context: "SlackMonitoringService.logToFile.write")
                }
            }
        }
        
        // Use structured logging instead of debugPrint
        Logger.shared.logInfo(message)
    }
    
    // MARK: - Public API
    
    /// Start monitoring Slack application
    public func startMonitoring() async {
        guard !isMonitoring else {
            logToFile("⚠️ Slack monitoring already started")
            return
        }
        
        logToFile("ℹ️ Starting Slack monitoring service")
        
        // Initialize services
        await initializeServices()
        
        // Start monitoring
        isMonitoring = true
        currentRetryCount = 0
        loadMonitoringState()
        
        monitoringTask = Task { [weak self] in
            await self?.monitorLoop()
        }
    }
    
    /// Stop monitoring Slack application
    public func stopMonitoring() {
        guard isMonitoring else {
            logToFile("Slack monitoring not currently running")
            return
        }
        
        logToFile("Stopping Slack monitoring service")
        isMonitoring = false
        saveMonitoringState()
        
        cleanupService.stopPeriodicCleanup()
        logToFile("✅ Database cleanup service stopped")
        
        // Properly cancel and clean up the monitoring task
        if let task = monitoringTask {
            task.cancel()
            monitoringTask = nil
        }
        currentRetryCount = 0
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
            contentParsingEnabled: config.contentParsingEnabled,
            cleanupEnabled: cleanupService.cleanupEnabled,
            lastCleanupDate: cleanupService.lastCleanupDate,
            retentionPeriod: cleanupService.getRetentionDescription()
        )
    }
    
    /// Enable or disable content parsing
    public func setContentParsingEnabled(_ enabled: Bool) {
        config.contentParsingEnabled = enabled
        logToFile("Content parsing \(enabled ? "enabled" : "disabled")")
    }
    
    /// Enable or disable background monitoring
    public func setBackgroundMonitoringEnabled(_ enabled: Bool) {
        config.backgroundMonitoringEnabled = enabled
        logToFile("Background monitoring \(enabled ? "enabled" : "disabled")")
        saveMonitoringState()
    }
    
    /// Clear extracted content history
    public func clearExtractedContent() {
        lastExtractedConversation = nil
        extractionHistory.removeAll()
        logToFile("📋 Extracted content history cleared")
    }
    
    // MARK: - Private Methods
    
    private func initializeServices() async {
        // Initialize database
        do {
            try await vectorService.initialize()
            logToFile("✅ Vector database initialized for Slack ingestion")
            
            if let database = vectorService.getDatabase() as? SlackDatabaseSchema {
                cleanupService.setDatabase(database)
                cleanupService.startPeriodicCleanup()
                logToFile("✅ Database cleanup service started (2-month retention)")
            }
        } catch {
            logToFile("⚠️ Vector database initialization failed: \(error)")
            logToFile("   Monitoring will continue but data won't be persisted")
        }
        
        // Check accessibility permissions
        let accessibilityStatus = await accessibilityManager.requestAccessibilityPermissions()
        config.contentParsingEnabled = (accessibilityStatus != .permissionDenied)
        
        if config.contentParsingEnabled {
            logToFile("✅ Accessibility permissions granted - content parsing enabled")
        } else {
            logToFile("❌ Accessibility permissions required for content parsing")
            logToFile("   Content parsing will be disabled until permissions are granted")
        }
    }
    
    private func monitorLoop() async {
        logToFile("ℹ️ Starting monitoring loop")
        
        while isMonitoring && !Task.isCancelled {
            do {
                await processMonitoringCycle()
                try await Task.sleep(for: .seconds(currentPollInterval))
            } catch {
                await handleMonitoringError(error)
            }
        }
        
        logToFile("ℹ️ Monitoring loop ended")
    }
    
    private func processMonitoringCycle() async {
        guard let slackState = await appObserver.getSlackAppState() else {
            logToFile("🔍 Scanning for Slack... (not currently running)")
            currentPollInterval = config.pollIntervalInactive
            return
        }
        
        if slackState.isActive {
            await handleActiveSlack(slackState)
        } else {
            await handleInactiveSlack(slackState)
        }
    }
    
    private func handleActiveSlack(_ slackState: AppState) async {
        logToFile("✅ SLACK DETECTED! Slack is active and ready for monitoring")
        logToFile("   📊 PID: \(slackState.pid), Name: \(slackState.name)")
        
        currentRetryCount = 0
        currentPollInterval = config.pollIntervalActive
        
        if config.contentParsingEnabled {
            await extractContent(from: slackState)
        } else {
            logToFile("   ℹ️ Content parsing disabled (accessibility permissions needed)")
        }
    }
    
    private func handleInactiveSlack(_ slackState: AppState) async {
        if config.backgroundMonitoringEnabled {
            logToFile("🟡 Slack is running but not in focus - continuing background monitoring")
            currentPollInterval = config.pollIntervalBackground
            
            if config.contentParsingEnabled {
                await extractContent(from: slackState)
            }
        } else {
            logToFile("⏸️ Slack not in focus - background monitoring disabled")
            currentPollInterval = config.pollIntervalInactive
        }
    }
    
    private func extractContent(from slackState: AppState) async {
        do {
            logToFile("   🔍 Creating LBAccessibility element for PID: \(slackState.pid)")
            let slackApplication = Element(processIdentifier: slackState.pid)
            logToFile("   ✅ Created LBAccessibility element, attempting content extraction...")
            
            if let conversation = try await slackParser.parseCurrentConversation(
                from: slackApplication,
                timeout: 30.0
            ) {
                await handleExtractedContent(conversation)
            } else {
                logToFile("   📝 No active conversation detected by parser")
            }
        } catch {
            logToFile("   ⚠️ Content extraction failed: \(error.localizedDescription)")
        }
    }
    
    private func handleExtractedContent(_ conversation: SlackConversation) async {
        logToFile("   📋 CONTENT EXTRACTED!")
        logToFile("      Workspace: \(conversation.workspace)")
        logToFile("      Channel: \(conversation.channel) (\(conversation.channelType))")
        logToFile("      Messages: \(conversation.messages.count)")
        
        if let recentMessage = conversation.messages.last {
            let preview = String(recentMessage.content.prefix(50))
            let suffix = recentMessage.content.count > 50 ? "..." : ""
            logToFile("      Latest: [\(recentMessage.sender)] \(preview)\(suffix)")
        }
        
        // Update UI
        await updateUI(with: conversation)
        
        // Ingest to database
        if let database = vectorService.getDatabase() as? SlackDatabaseSchema {
            await ingestionService.ingestConversation(conversation, to: database)
        }
    }
    
    private func updateUI(with conversation: SlackConversation) async {
        lastExtractedConversation = conversation
        extractionHistory.append(conversation)
        
        logToFile("   🎯 UI UPDATE: Sending \(conversation.messages.count) messages to UI")
        saveMonitoringState()
        
        // Keep only last N extractions to prevent unbounded growth
        while extractionHistory.count > config.maxExtractionHistory {
            extractionHistory.removeFirst()
        }
    }
    
    private func handleMonitoringError(_ error: Error) async {
        if error is CancellationError {
            logToFile("ℹ️ Monitoring task cancelled")
            return
        }
        
        currentRetryCount += 1
        
        if currentRetryCount <= config.maxRetries {
            logToFile("⚠️ Monitoring error (retry \(currentRetryCount)/\(config.maxRetries)): \(error.localizedDescription)")
            
            do {
                try await Task.sleep(for: .seconds(config.retryDelay))
            } catch {
                return
            }
        } else {
            logToFile("❌ Max retries exceeded, continuing with reduced frequency")
            currentRetryCount = 0
            
            do {
                try await Task.sleep(for: .seconds(config.retryDelay * 2))
            } catch {
                return
            }
        }
    }
    
    // MARK: - State Persistence
    
    private func saveMonitoringState() {
        let state = MonitoringState(
            isMonitoring: isMonitoring,
            backgroundMonitoringEnabled: config.backgroundMonitoringEnabled,
            contentParsingEnabled: config.contentParsingEnabled,
            lastExtractedTimestamp: lastExtractedConversation?.messages.last?.timestamp,
            extractionHistoryCount: extractionHistory.count
        )
        
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: "SlunkMonitoringState")
        }
    }
    
    private func loadMonitoringState() {
        guard let data = UserDefaults.standard.data(forKey: "SlunkMonitoringState"),
              let state = try? JSONDecoder().decode(MonitoringState.self, from: data) else {
            return
        }
        
        config.backgroundMonitoringEnabled = state.backgroundMonitoringEnabled
        config.contentParsingEnabled = state.contentParsingEnabled
        
        logToFile("💾 Loaded monitoring state:")
        logToFile("   Background monitoring: \(state.backgroundMonitoringEnabled)")
        logToFile("   Content parsing: \(state.contentParsingEnabled)")
        logToFile("   Last extraction: \(state.lastExtractedTimestamp?.description ?? "none")")
    }
}

// MARK: - Supporting Types

/// Monitoring state for persistence
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
        
        if status.retryCount > config.maxRetries {
            return .unhealthy("Excessive retry attempts", details: [
                "retryCount": "\(status.retryCount)",
                "maxRetries": "\(config.maxRetries)"
            ])
        }
        
        return .healthy
    }
}

// Keep existing SlackAppObserver and ServiceStatus as they are...

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
                Logger.shared.logInfo("✅ Found Slack app by name: \(appName), PID: \(app.processIdentifier)")
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
}