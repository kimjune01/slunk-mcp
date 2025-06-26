import Foundation
import GRDB

/// Service responsible for managing database size by implementing forgetting policies
/// Prevents indefinite growth by removing old messages based on configurable retention periods
@MainActor
public final class DatabaseCleanupService: ObservableObject {
    public static let shared = DatabaseCleanupService()
    
    // MARK: - Configuration
    
    /// Default retention period: 2 months
    private static let defaultRetentionPeriod: TimeInterval = 2 * 30 * 24 * 60 * 60 // 2 months in seconds
    
    /// Cleanup check interval: 1 hour
    private static let cleanupInterval: TimeInterval = 60 * 60 // 1 hour in seconds
    
    /// Batch size for deletion operations to avoid memory spikes
    private static let deletionBatchSize = 1000
    
    // MARK: - State
    
    @Published public private(set) var isCleanupEnabled = true
    @Published public private(set) var lastCleanupDate: Date?
    @Published public private(set) var cleanupStats: CleanupStats?
    
    private var cleanupTimer: Timer?
    private var database: SlackDatabaseSchema?
    
    // MARK: - Configuration Properties
    
    /// Retention period in seconds (configurable)
    public var retentionPeriod: TimeInterval {
        get {
            UserDefaults.standard.object(forKey: "SlunkRetentionPeriod") as? TimeInterval ?? Self.defaultRetentionPeriod
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "SlunkRetentionPeriod")
        }
    }
    
    /// Whether cleanup is enabled
    public var cleanupEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: "SlunkCleanupEnabled") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "SlunkCleanupEnabled")
            isCleanupEnabled = newValue
            if newValue {
                startPeriodicCleanup()
            } else {
                stopPeriodicCleanup()
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        loadState()
    }
    
    deinit {
        Task { @MainActor in
            self.stopPeriodicCleanup()
        }
    }
    
    // MARK: - Public Interface
    
    /// Set the database instance to clean up
    func setDatabase(_ database: SlackDatabaseSchema) {
        self.database = database
        debugPrint("📁 Database cleanup service configured with database")
    }
    
    /// Start the periodic cleanup timer
    public func startPeriodicCleanup() {
        guard cleanupEnabled else {
            debugPrint("⏸️ Database cleanup disabled - timer not started")
            return
        }
        
        guard cleanupTimer == nil else {
            debugPrint("⚠️ Cleanup timer already running")
            return
        }
        
        debugPrint("⏰ Starting database cleanup timer (checking every hour)")
        
        // Start timer for hourly checks
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: Self.cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performScheduledCleanup()
            }
        }
        
        // Perform initial cleanup after a short delay
        Task {
            try await Task.sleep(for: .seconds(30))
            await performScheduledCleanup()
        }
    }
    
    /// Stop the periodic cleanup timer
    public func stopPeriodicCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        debugPrint("⏹️ Database cleanup timer stopped")
    }
    
    /// Manually trigger cleanup operation
    public func performManualCleanup() async -> CleanupStats {
        debugPrint("🗑️ Manual database cleanup requested")
        return await performCleanup(isManual: true)
    }
    
    /// Get current retention cutoff date
    public func getRetentionCutoffDate() -> Date {
        return Date().addingTimeInterval(-retentionPeriod)
    }
    
    /// Get human-readable retention period
    public func getRetentionDescription() -> String {
        let days = Int(retentionPeriod / (24 * 60 * 60))
        let months = days / 30
        
        if months > 0 {
            return "\(months) month\(months == 1 ? "" : "s")"
        } else {
            return "\(days) day\(days == 1 ? "" : "s")"
        }
    }
    
    // MARK: - Private Implementation
    
    private func loadState() {
        isCleanupEnabled = cleanupEnabled
        lastCleanupDate = UserDefaults.standard.object(forKey: "SlunkLastCleanupDate") as? Date
        
        // Load last cleanup stats if available
        if let statsData = UserDefaults.standard.data(forKey: "SlunkLastCleanupStats"),
           let stats = try? JSONDecoder().decode(CleanupStats.self, from: statsData) {
            cleanupStats = stats
        }
    }
    
    private func saveState() {
        UserDefaults.standard.set(lastCleanupDate, forKey: "SlunkLastCleanupDate")
        
        if let stats = cleanupStats,
           let statsData = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(statsData, forKey: "SlunkLastCleanupStats")
        }
    }
    
    private func performScheduledCleanup() async {
        guard cleanupEnabled else { return }
        
        // Check if enough time has passed since last cleanup (at least 50 minutes to avoid overlaps)
        if let lastCleanup = lastCleanupDate,
           Date().timeIntervalSince(lastCleanup) < 50 * 60 {
            return
        }
        
        debugPrint("⏰ Scheduled database cleanup starting")
        let stats = await performCleanup(isManual: false)
        
        if stats.messagesDeleted > 0 {
            debugPrint("✅ Scheduled cleanup completed - deleted \(stats.messagesDeleted) old messages")
        }
    }
    
    private func performCleanup(isManual: Bool) async -> CleanupStats {
        guard let database = database else {
            debugPrint("⚠️ Cannot perform cleanup - no database configured")
            return CleanupStats(
                startDate: Date(),
                endDate: Date(),
                cutoffDate: getRetentionCutoffDate(),
                messagesDeleted: 0,
                reactionsDeleted: 0,
                embeddingsDeleted: 0,
                spaceSavedBytes: 0,
                isManual: isManual,
                error: "No database configured"
            )
        }
        
        let startDate = Date()
        let cutoffDate = getRetentionCutoffDate()
        
        debugPrint("🗑️ Starting database cleanup:")
        debugPrint("   Cutoff date: \(cutoffDate)")
        debugPrint("   Retention period: \(getRetentionDescription())")
        debugPrint("   Manual: \(isManual)")
        
        var stats = CleanupStats(
            startDate: startDate,
            endDate: Date(),
            cutoffDate: cutoffDate,
            messagesDeleted: 0,
            reactionsDeleted: 0,
            embeddingsDeleted: 0,
            spaceSavedBytes: 0,
            isManual: isManual
        )
        
        do {
            // Get database size before cleanup
            let sizeBefore = try await getDatabaseSize(database)
            
            // Delete old messages, reactions, and embeddings
            let deletedMessages = try await deleteOldMessages(database: database, cutoffDate: cutoffDate)
            let deletedReactions = try await deleteOldReactions(database: database, cutoffDate: cutoffDate)
            let deletedEmbeddings = try await deleteOldEmbeddings(database: database, cutoffDate: cutoffDate)
            
            // Vacuum database to reclaim space
            try await vacuumDatabase(database)
            
            // Get database size after cleanup
            let sizeAfter = try await getDatabaseSize(database)
            let spaceSaved = sizeBefore > sizeAfter ? sizeBefore - sizeAfter : 0
            
            stats.messagesDeleted = deletedMessages
            stats.reactionsDeleted = deletedReactions
            stats.embeddingsDeleted = deletedEmbeddings
            stats.spaceSavedBytes = spaceSaved
            stats.endDate = Date()
            
            // Update state
            lastCleanupDate = startDate
            cleanupStats = stats
            saveState()
            
            debugPrint("✅ Database cleanup completed:")
            debugPrint("   Messages deleted: \(deletedMessages)")
            debugPrint("   Reactions deleted: \(deletedReactions)")
            debugPrint("   Embeddings deleted: \(deletedEmbeddings)")
            debugPrint("   Space saved: \(formatBytes(spaceSaved))")
            debugPrint("   Duration: \(String(format: "%.2f", stats.duration))s")
            
        } catch {
            stats.error = error.localizedDescription
            stats.endDate = Date()
            
            debugPrint("❌ Database cleanup failed: \(error.localizedDescription)")
        }
        
        return stats
    }
    
    private func deleteOldMessages(database: SlackDatabaseSchema, cutoffDate: Date) async throws -> Int {
        guard let db = database.database else {
            throw CleanupError.databaseNotAvailable
        }
        
        var totalDeleted = 0
        
        // Delete in batches to avoid memory issues
        repeat {
            let deleted = try await db.write { db in
                let statement = try db.makeStatement(sql: """
                    DELETE FROM slack_messages 
                    WHERE timestamp < ? 
                    AND rowid IN (
                        SELECT rowid FROM slack_messages 
                        WHERE timestamp < ? 
                        LIMIT ?
                    )
                """)
                try statement.execute(arguments: [cutoffDate, cutoffDate, Self.deletionBatchSize])
                return db.changesCount
            }
            
            totalDeleted += deleted
            
            if deleted < Self.deletionBatchSize {
                break // No more rows to delete
            }
            
            // Small delay between batches to avoid blocking
            try await Task.sleep(for: .milliseconds(100))
            
        } while true
        
        return totalDeleted
    }
    
    private func deleteOldReactions(database: SlackDatabaseSchema, cutoffDate: Date) async throws -> Int {
        guard let db = database.database else {
            throw CleanupError.databaseNotAvailable
        }
        
        // Delete reactions for messages that no longer exist (they were deleted above)
        let deleted = try await db.write { db in
            let statement = try db.makeStatement(sql: """
                DELETE FROM slack_reactions 
                WHERE message_id NOT IN (
                    SELECT id FROM slack_messages
                )
            """)
            try statement.execute()
            return db.changesCount
        }
        
        return deleted
    }
    
    private func deleteOldEmbeddings(database: SlackDatabaseSchema, cutoffDate: Date) async throws -> Int {
        guard let db = database.database else {
            throw CleanupError.databaseNotAvailable
        }
        
        // Delete embeddings for messages that no longer exist
        let deleted = try await db.write { db in
            let statement = try db.makeStatement(sql: """
                DELETE FROM slack_message_embeddings 
                WHERE message_id NOT IN (
                    SELECT id FROM slack_messages
                )
            """)
            try statement.execute()
            return db.changesCount
        }
        
        return deleted
    }
    
    private func vacuumDatabase(_ database: SlackDatabaseSchema) async throws {
        guard let db = database.database else {
            throw CleanupError.databaseNotAvailable
        }
        
        try await db.write { db in
            let statement = try db.makeStatement(sql: "VACUUM")
            try statement.execute()
        }
    }
    
    private func getDatabaseSize(_ database: SlackDatabaseSchema) async throws -> UInt64 {
        let fileURL = database.databaseURL
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attributes[.size] as? UInt64 ?? 0
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Supporting Types

public struct CleanupStats: Codable {
    public let startDate: Date
    public var endDate: Date
    public let cutoffDate: Date
    public var messagesDeleted: Int
    public var reactionsDeleted: Int
    public var embeddingsDeleted: Int
    public var spaceSavedBytes: UInt64
    public let isManual: Bool
    public var error: String?
    
    public var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    public var wasSuccessful: Bool {
        return error == nil
    }
}

enum CleanupError: Error, LocalizedError {
    case databaseNotAvailable
    case deletionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseNotAvailable:
            return "Database not available for cleanup"
        case .deletionFailed(let message):
            return "Deletion failed: \(message)"
        }
    }
}

// MARK: - Configuration Extensions

extension DatabaseCleanupService {
    /// Set retention period in months
    public func setRetentionMonths(_ months: Int) {
        retentionPeriod = TimeInterval(months * 30 * 24 * 60 * 60)
        debugPrint("📅 Retention period set to \(months) months")
    }
    
    /// Set retention period in days
    public func setRetentionDays(_ days: Int) {
        retentionPeriod = TimeInterval(days * 24 * 60 * 60)
        debugPrint("📅 Retention period set to \(days) days")
    }
    
    /// Get estimated messages that would be deleted in next cleanup
    public func getEstimatedDeletionCount() async -> Int {
        guard let database = database,
              let db = database.database else {
            return 0
        }
        
        do {
            let cutoffDate = getRetentionCutoffDate()
            let count = try await db.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM slack_messages WHERE timestamp < ?", arguments: [cutoffDate]) ?? 0
            }
            return count
        } catch {
            debugPrint("⚠️ Failed to estimate deletion count: \(error)")
            return 0
        }
    }
}