import Foundation

// MARK: - Production Service Manager

@MainActor
class ProductionService: ObservableObject {
    static let shared = ProductionService()
    
    @Published var isInitialized = false
    @Published var isLoading = false
    @Published var lastError: Error?
    @Published var statistics: ServiceStatistics?
    
    private var schema: SQLiteVecSchema?
    private var queryEngine: NaturalLanguageQueryEngine?
    private var smartIngestion: SmartIngestionService?
    private var dataSeeder: DataSeeder?
    private var maintenanceTimer: Timer?
    private var cleanupService: DatabaseCleanupService?
    
    private init() {}
    
    // MARK: - Initialization
    
    func initialize() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Initialize database
            Logger.shared.logDatabaseOperation("Initializing production database")
            let dbPath = Configuration.shared.databaseURL.path
            schema = SQLiteVecSchema(databasePath: dbPath)
            
            guard let schema = schema else {
                throw SlunkError.databaseInitializationFailed("Schema creation failed")
            }
            
            try await schema.initializeDatabase()
            
            // Apply optimizations
            if FeatureFlags.isDatabaseOptimizationEnabled {
                let optimizer = DatabaseOptimizer()
                try await optimizer.applyOptimizations(to: schema)
                try await optimizer.optimizeIndexes(on: schema)
                Logger.shared.logDatabaseOperation("Database optimizations applied")
            }
            
            // Initialize services
            queryEngine = NaturalLanguageQueryEngine()
            queryEngine?.setDatabase(schema)
            
            smartIngestion = SmartIngestionService()
            await smartIngestion?.setDatabase(schema)
            
            dataSeeder = DataSeeder()
            await dataSeeder?.setDatabase(schema)
            
            // Initialize cleanup service for Slack database
            // Note: We'll need to check if we're working with Slack data and create appropriate schema
            cleanupService = DatabaseCleanupService.shared
            // TODO: Integrate cleanup service when SlackDatabaseSchema is available
            Logger.shared.logDatabaseOperation("Database cleanup service configured")
            
            // Seed initial data if needed
            if FeatureFlags.isDataSeedingEnabled && !UserDefaultsManager.shared.onboardingCompleted {
                await seedInitialData()
                UserDefaultsManager.shared.onboardingCompleted = true
            }
            
            // Load statistics
            await loadStatistics()
            
            // Start maintenance timer
            startMaintenanceTimer()
            
            isInitialized = true
            Logger.shared.logDatabaseOperation("Production service initialized successfully")
            
        } catch {
            lastError = error
            Logger.shared.logDatabaseError(error, context: "ProductionService.initialize")
            throw error
        }
    }
    
    // MARK: - Public Methods
    
    func getDatabase() -> SQLiteVecSchema? {
        return schema
    }
    
    func search(query: String) async throws -> [QueryResult] {
        guard isInitialized else {
            throw SlunkError.databaseInitializationFailed("Service not initialized")
        }
        
        let timer = PerformanceTimer(operation: "search")
        defer { timer.stop() }
        
        do {
            // Validate input
            let sanitizedQuery = try InputSanitizer.validateInput(
                query,
                maxLength: Configuration.Query.maxQueryLength
            )
            
            // Parse and execute query
            guard let engine = queryEngine else {
                throw SlunkError.resourceNotFound("Query engine not available")
            }
            
            let parsedQuery = engine.parseQuery(sanitizedQuery)
            let results = try await engine.safeExecuteHybridSearch(
                parsedQuery,
                limit: UserDefaultsManager.shared.preferredQueryLimit
            )
            
            // Update statistics
            UserDefaultsManager.shared.incrementQueryCount()
            timer.addMetadata(key: "resultCount", value: results.count)
            
            Logger.shared.logQuery(sanitizedQuery, resultCount: results.count, duration: 0)
            
            return results
            
        } catch {
            Logger.shared.logQueryError(error, query: query)
            throw error
        }
    }
    
    func ingest(
        content: String,
        title: String,
        summary: String,
        sender: String? = nil
    ) async throws -> IngestionResult {
        guard isInitialized else {
            throw SlunkError.databaseInitializationFailed("Service not initialized")
        }
        
        let timer = PerformanceTimer(operation: "ingest")
        defer { timer.stop() }
        
        do {
            guard let ingestion = smartIngestion else {
                throw SlunkError.resourceNotFound("Ingestion service not available")
            }
            
            let result = try await ingestion.safeIngestText(
                content: content,
                title: title,
                summary: summary,
                sender: sender,
                timestamp: Date()
            )
            
            // Update statistics
            UserDefaultsManager.shared.incrementIngestionCount()
            timer.addMetadata(key: "keywords", value: result.extractedKeywords.count)
            
            Logger.shared.logIngestion(
                title: title,
                keywords: result.extractedKeywords.count,
                duration: 0
            )
            
            // Reload statistics in background
            Task { await loadStatistics() }
            
            return result
            
        } catch {
            Logger.shared.logIngestionError(error, title: title)
            throw error
        }
    }
    
    func getStatistics() async throws -> ServiceStatistics {
        guard isInitialized else {
            throw SlunkError.databaseInitializationFailed("Service not initialized")
        }
        
        guard let schema = schema else {
            throw SlunkError.resourceNotFound("Database not available")
        }
        
        return try await loadStatisticsFromDatabase(schema)
    }
    
    // MARK: - Private Methods
    
    private func seedInitialData() async {
        do {
            guard let seeder = dataSeeder else { return }
            
            Logger.shared.logDatabaseOperation("Seeding initial data")
            let result = try await seeder.seedIfEmpty()
            
            Logger.shared.logDatabaseOperation(
                "Seeded \(result.itemsSeeded) conversations in \(String(format: "%.2f", result.processingTime))s"
            )
        } catch {
            Logger.shared.logDatabaseError(error, context: "seedInitialData")
            // Don't throw - seeding is optional
        }
    }
    
    private func loadStatistics() async {
        guard let schema = schema else { return }
        
        do {
            statistics = try await loadStatisticsFromDatabase(schema)
        } catch {
            Logger.shared.logError(error, context: "loadStatistics")
        }
    }
    
    private func loadStatisticsFromDatabase(_ schema: SQLiteVecSchema) async throws -> ServiceStatistics {
        let stats = try await schema.getTableStatistics()
        let summariesCount = stats["text_summaries"]?.rowCount ?? 0
        let embeddingsCount = stats["summary_embeddings"]?.rowCount ?? 0
        
        return ServiceStatistics(
            totalConversations: summariesCount,
            totalEmbeddings: embeddingsCount,
            totalQueries: UserDefaultsManager.shared.totalQueries,
            totalIngestions: UserDefaultsManager.shared.totalIngestions,
            databaseSize: try await schema.getDatabaseSize()
        )
    }
    
    private func startMaintenanceTimer() {
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { await self.performMaintenance() }
        }
    }
    
    private func performMaintenance() async {
        guard let schema = schema else { return }
        
        // Check if vacuum needed
        let lastVacuum = UserDefaultsManager.shared.lastVacuumDate ?? Date.distantPast
        let timeSinceVacuum = Date().timeIntervalSince(lastVacuum)
        
        if timeSinceVacuum > Configuration.Database.vacuumInterval {
            do {
                Logger.shared.logDatabaseOperation("Performing scheduled maintenance")
                
                let optimizer = DatabaseOptimizer()
                try await optimizer.performVacuum(on: schema)
                try await optimizer.performAnalyze(on: schema)
                
                UserDefaultsManager.shared.lastVacuumDate = Date()
                Logger.shared.logDatabaseOperation("Maintenance completed")
            } catch {
                Logger.shared.logDatabaseError(error, context: "performMaintenance")
            }
        }
        
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
        maintenanceTimer?.invalidate()
        Task { @MainActor in
            cleanupService?.stopPeriodicCleanup()
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

// MARK: - Production MCP Integration

extension ProductionService {
    func handleMCPRequest(method: String, params: [String: Any]?) async throws -> Any {
        guard isInitialized else {
            throw SlunkError.databaseInitializationFailed("Service not initialized")
        }
        
        let timer = PerformanceTimer(operation: "mcp_\(method)")
        Logger.shared.logMCPRequest(method: method, params: params)
        
        do {
            let result: Any
            
            switch method {
            case "searchConversations":
                let query = params?["query"] as? String ?? ""
                let limit = params?["limit"] as? Int ?? Configuration.Query.defaultLimit
                
                guard let engine = queryEngine else {
                    throw SlunkError.resourceNotFound("Query engine not available")
                }
                
                let parsedQuery = engine.parseQuery(query)
                let searchResults = try await engine.safeExecuteHybridSearch(parsedQuery, limit: limit)
                
                result = searchResults.map { queryResult in
                    [
                        "id": queryResult.summary.id.uuidString,
                        "title": queryResult.summary.title,
                        "summary": queryResult.summary.summary,
                        "score": queryResult.combinedScore
                    ]
                }
                
            case "ingestText":
                let content = params?["content"] as? String ?? ""
                let title = params?["title"] as? String ?? ""
                let summary = params?["summary"] as? String ?? ""
                let sender = params?["sender"] as? String
                
                guard let ingestion = smartIngestion else {
                    throw SlunkError.resourceNotFound("Ingestion service not available")
                }
                
                let ingestionResult = try await ingestion.ingestText(
                    content: content,
                    title: title,
                    summary: summary.isEmpty ? content : summary,
                    sender: sender
                )
                
                result = [
                    "id": ingestionResult.summaryId,
                    "keywords": ingestionResult.extractedKeywords,
                    "processingTime": ingestionResult.processingTime,
                    "embeddingDimensions": ingestionResult.embeddingDimensions
                ]
            
            default:
                throw SlunkError.invalidInput("Unknown method: \(method)")
            }
            
            Logger.shared.logMCPResponse(method: method, success: true, duration: 0)
            return result
            
        } catch {
            Logger.shared.logMCPResponse(method: method, success: false, duration: 0)
            throw error
        }
    }
}
