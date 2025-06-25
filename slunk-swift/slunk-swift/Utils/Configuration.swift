import Foundation

// MARK: - Configuration Manager

class Configuration {
    static let shared = Configuration()
    
    // MARK: - Database Settings
    struct Database {
        static let fileName = "slunk_conversations.db"
        static let walCheckpointThreshold = 1000
        static let vacuumInterval: TimeInterval = 86400 // 24 hours
        static let maxDatabaseSize: Int64 = 1_073_741_824 // 1GB
    }
    
    // MARK: - Query Settings
    struct Query {
        static let defaultLimit = 10
        static let maxLimit = 100
        static let minQueryLength = 1
        static let maxQueryLength = 500
        static let searchTimeout: TimeInterval = 5.0
        static let hybridSearchWeights = (semantic: 0.6, keyword: 0.4)
    }
    
    // MARK: - Ingestion Settings
    struct Ingestion {
        static let maxContentLength = 100_000
        static let maxTitleLength = 500
        static let maxSummaryLength = 5000
        static let maxKeywords = 20
        static let minKeywordLength = 2
        static let batchSize = 100
    }
    
    // MARK: - Performance Settings
    struct Performance {
        static let maxConcurrentOperations = 50
        static let memoryWarningThreshold: Double = 0.8
        static let cacheSizeMB = 64
        static let mmapSizeMB = 256
        static let queryTimeoutSeconds = 30
    }
    
    // MARK: - MCP Settings
    struct MCP {
        static let serverName = "slunk"
        static let version = "1.0.0"
        static let maxRequestSize = 10_485_760 // 10MB
        static let requestTimeout: TimeInterval = 30.0
    }
    
    // MARK: - File Paths
    
    var databaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Slunk", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDir,
                                               withIntermediateDirectories: true,
                                               attributes: nil)
        
        return appDir.appendingPathComponent(Database.fileName)
    }
    
    var logDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first!
        let logDir = appSupport.appendingPathComponent("Slunk/Logs", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: logDir,
                                               withIntermediateDirectories: true,
                                               attributes: nil)
        
        return logDir
    }
    
    // MARK: - Environment
    
    var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    var isTestEnvironment: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    private init() {}
}

// MARK: - User Defaults Manager

class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private let defaults = UserDefaults.standard
    private let suiteName = "com.slunk.preferences"
    
    private enum Keys {
        static let lastVacuumDate = "lastVacuumDate"
        static let totalQueries = "totalQueries"
        static let totalIngestions = "totalIngestions"
        static let onboardingCompleted = "onboardingCompleted"
        static let preferredQueryLimit = "preferredQueryLimit"
    }
    
    var lastVacuumDate: Date? {
        get { defaults.object(forKey: Keys.lastVacuumDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastVacuumDate) }
    }
    
    var totalQueries: Int {
        get { defaults.integer(forKey: Keys.totalQueries) }
        set { defaults.set(newValue, forKey: Keys.totalQueries) }
    }
    
    var totalIngestions: Int {
        get { defaults.integer(forKey: Keys.totalIngestions) }
        set { defaults.set(newValue, forKey: Keys.totalIngestions) }
    }
    
    var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Keys.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Keys.onboardingCompleted) }
    }
    
    var preferredQueryLimit: Int {
        get {
            let limit = defaults.integer(forKey: Keys.preferredQueryLimit)
            return limit > 0 ? limit : Configuration.Query.defaultLimit
        }
        set {
            let validLimit = min(max(1, newValue), Configuration.Query.maxLimit)
            defaults.set(validLimit, forKey: Keys.preferredQueryLimit)
        }
    }
    
    func incrementQueryCount() {
        totalQueries += 1
    }
    
    func incrementIngestionCount() {
        totalIngestions += 1
    }
    
    private init() {}
}

// MARK: - Feature Flags

struct FeatureFlags {
    static var isVectorSearchEnabled = true
    static var isKeywordSearchEnabled = true
    static var isAutoKeywordExtractionEnabled = true
    static var isDataSeedingEnabled = true
    static var isDatabaseOptimizationEnabled = true
    static var isMemoryMonitoringEnabled = true
    static var isConcurrencyLimitEnabled = true
    static var isErrorLoggingEnabled = true
    
    // Experimental features
    static var isExperimentalQueryParsingEnabled = false
    static var isExperimentalCachingEnabled = false
}

// MARK: - App Info

struct AppInfo {
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.slunk.app"
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    static var fullVersion: String {
        return "\(version) (\(build))"
    }
    
    static var userAgent: String {
        return "Slunk/\(version) (macOS; \(ProcessInfo.processInfo.operatingSystemVersionString))"
    }
}