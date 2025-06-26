import Foundation

// MARK: - Production Service Manager

@MainActor
class ProductionService: ObservableObject {
    static let shared = ProductionService()
    
    @Published var isInitialized = false
    @Published var isLoading = false
    @Published var lastError: Error?
    @Published var statistics: ServiceStatistics?
    
    private var schema: SlackDatabaseSchema?
    private var cleanupService: DatabaseCleanupService?
    
    private init() {}
    
    // MARK: - Initialization
    
    func initialize() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Initialize database
            Logger.shared.logDatabaseOperation("Initializing production database")
            schema = try SlackDatabaseSchema()
            
            guard let schema = schema else {
                throw SlunkError.databaseInitializationFailed("Schema creation failed")
            }
            
            try await schema.initializeDatabase()
            
            // Initialize cleanup service for Slack database
            cleanupService = DatabaseCleanupService.shared
            cleanupService?.setDatabase(schema)
            Logger.shared.logDatabaseOperation("Database cleanup service configured")
            
            Logger.shared.logDatabaseOperation("SlackDatabaseSchema ready for Slack monitoring")
            
            isInitialized = true
            Logger.shared.logDatabaseOperation("Production service initialized successfully")
            
        } catch {
            lastError = error
            Logger.shared.logDatabaseError(error, context: "ProductionService.initialize")
            throw error
        }
    }
    
    // MARK: - Public Methods
    
    func getDatabase() -> SlackDatabaseSchema? {
        return schema
    }
    
    // MARK: - Slack Database Operations
    
    func getDatabaseStats() async throws -> DatabaseStats {
        guard let schema = schema else {
            throw SlunkError.databaseInitializationFailed("Database not initialized")
        }
        
        let tableStats = try await schema.getTableStatistics()
        let databaseSize = try await schema.getDatabaseSize()
        
        return DatabaseStats(
            totalSize: UInt64(databaseSize),
            tableStatistics: tableStats,
            lastUpdated: Date()
        )
    }
    
    func optimizeDatabase() async throws {
        guard let schema = schema else {
            throw SlunkError.databaseInitializationFailed("Database not initialized")
        }
        
        let optimizer = DatabaseOptimizer()
        try await optimizer.applyOptimizations(to: schema)
        try await optimizer.optimizeIndexes(on: schema)
        
        Logger.shared.logDatabaseOperation("Database optimization completed")
    }
    
    func getStatistics() async throws -> ServiceStatistics {
        guard isInitialized else {
            throw SlunkError.databaseInitializationFailed("Service not initialized")
        }
        
        guard let schema = schema else {
            throw SlunkError.databaseInitializationFailed("Database not initialized")
        }
        
        let messageCount = try await schema.getMessageCount()
        let workspaceCount = try await schema.getWorkspaceCount()
        let databaseSize = try await schema.getDatabaseSize()
        
        return ServiceStatistics(
            totalConversations: messageCount,
            totalEmbeddings: 0, // TODO: Add embedding count query
            totalQueries: 0,
            totalIngestions: messageCount,
            databaseSize: UInt64(databaseSize)
        )
    }
    
    // MARK: - Private Methods
    
    private func loadStatistics() async {
        do {
            statistics = try await getStatistics()
        } catch {
            Logger.shared.logError(error, context: "ProductionService.loadStatistics")
            statistics = ServiceStatistics(
                totalConversations: 0,
                totalEmbeddings: 0,
                totalQueries: 0,
                totalIngestions: 0,
                databaseSize: 0
            )
        }
    }
    
    private func performMaintenance() async {
        // Database cleanup is handled by DatabaseCleanupService
        Logger.shared.logDatabaseOperation("Maintenance delegated to DatabaseCleanupService for Slack data")
        
        // Check memory pressure
        if FeatureFlags.isMemoryMonitoringEnabled {
            let monitor = MemoryMonitor()
            let usage = monitor.getCurrentMemoryUsage()
            let pressure = monitor.getMemoryPressure()
            
            if pressure == .high {
                Logger.shared.logMemoryWarning(usage: usage, pressure: pressure)
            }
        }
    }
    
    deinit {
        Task { [weak cleanupService] in
            await cleanupService?.stopPeriodicCleanup()
        }
    }
}

// MARK: - Service Statistics

struct ServiceStatistics {
    let totalConversations: Int
    let totalEmbeddings: Int
    let totalQueries: Int
    let totalIngestions: Int
    let databaseSize: UInt64
    
    var formattedDatabaseSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(databaseSize))
    }
}

// MARK: - Supporting Types

struct DatabaseStats {
    let totalSize: UInt64
    let tableStatistics: [String: TableStatistics]
    let lastUpdated: Date
}