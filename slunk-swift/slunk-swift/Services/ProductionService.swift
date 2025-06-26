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
            schema = try SlackDatabaseSchema()
            
            guard let schema = schema else {
                throw SlunkError.databaseInitializationFailed("Schema creation failed")
            }
            
            try await schema.initializeDatabase()
            
            // Note: Database optimizations and services are designed for SQLiteVecSchema
            // For Slack-specific functionality, we use SlackDatabaseSchema directly
            Logger.shared.logDatabaseOperation("Using SlackDatabaseSchema for Slack message storage")
            
            // Initialize cleanup service for Slack database
            cleanupService = DatabaseCleanupService.shared
            cleanupService?.setDatabase(schema)
            Logger.shared.logDatabaseOperation("Database cleanup service configured")
            
            // For Slack monitoring, no seeding or complex features needed
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
    
    func search(query: String) async throws -> [QueryResult] {
        // Search functionality not implemented for SlackDatabaseSchema
        // This ProductionService instance is used for Slack monitoring only
        throw SlunkError.resourceNotFound("Search not available with SlackDatabaseSchema")
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
        
        // Statistics not implemented for SlackDatabaseSchema
        return ServiceStatistics(
            totalConversations: 0,
            totalEmbeddings: 0,
            totalQueries: 0,
            totalIngestions: 0,
            databaseSize: 0
        )
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
        // Statistics not implemented for SlackDatabaseSchema
        statistics = ServiceStatistics(
            totalConversations: 0,
            totalEmbeddings: 0,
            totalQueries: 0,
            totalIngestions: 0,
            databaseSize: 0
        )
    }
    
    
    private func startMaintenanceTimer() {
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { await self.performMaintenance() }
        }
    }
    
    private func performMaintenance() async {
        // Maintenance not implemented for SlackDatabaseSchema
        // Database cleanup is handled by DatabaseCleanupService instead
        Logger.shared.logDatabaseOperation("Maintenance skipped - using DatabaseCleanupService for Slack data")
        
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
