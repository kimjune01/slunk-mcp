import Foundation

// MARK: - Production Error Types

enum SlunkError: LocalizedError {
    case databaseInitializationFailed(String)
    case ingestionFailed(String)
    case queryFailed(String)
    case embeddingGenerationFailed(String)
    case invalidInput(String)
    case resourceNotFound(String)
    case concurrencyLimitExceeded
    case memoryPressureHigh
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseInitializationFailed(let message):
            return "Database initialization failed: \(message)"
        case .ingestionFailed(let message):
            return "Failed to ingest content: \(message)"
        case .queryFailed(let message):
            return "Query execution failed: \(message)"
        case .embeddingGenerationFailed(let message):
            return "Failed to generate embedding: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .resourceNotFound(let message):
            return "Resource not found: \(message)"
        case .concurrencyLimitExceeded:
            return "Too many concurrent operations. Please try again."
        case .memoryPressureHigh:
            return "System memory is running low"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .databaseInitializationFailed:
            return "Check disk space and permissions"
        case .ingestionFailed:
            return "Verify content format and try again"
        case .queryFailed:
            return "Try simplifying your query"
        case .embeddingGenerationFailed:
            return "Ensure text is not empty and try again"
        case .invalidInput:
            return "Check input format and constraints"
        case .resourceNotFound:
            return "Verify the resource exists"
        case .concurrencyLimitExceeded:
            return "Wait a moment and retry"
        case .memoryPressureHigh:
            return "Close other applications and try again"
        case .networkError:
            return "Check your internet connection"
        }
    }
}

// MARK: - Error Logger

class ErrorLogger {
    static let shared = ErrorLogger()
    
    private let logQueue = DispatchQueue(label: "com.slunk.errorlog", qos: .utility)
    private var errorCount: [String: Int] = [:]
    
    private init() {}
    
    func log(_ error: Error, context: String? = nil) {
        logQueue.async { [weak self] in
            let errorKey = String(describing: type(of: error))
            self?.errorCount[errorKey, default: 0] += 1
            
            #if DEBUG
            print("❌ Error in \(context ?? "Unknown"): \(error.localizedDescription)")
            if let slunkError = error as? SlunkError,
               let suggestion = slunkError.recoverySuggestion {
                print("💡 Suggestion: \(suggestion)")
            }
            #endif
        }
    }
    
    func getErrorStatistics() -> [String: Int] {
        logQueue.sync {
            return errorCount
        }
    }
}

// MARK: - Retry Handler

struct RetryHandler {
    static func retry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 0.1,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxAttempts {
                    // Exponential backoff
                    let backoffDelay = delay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? SlunkError.queryFailed("Operation failed after \(maxAttempts) attempts")
    }
}

// MARK: - Input Sanitizer

struct InputSanitizer {
    static func sanitizeText(_ text: String) -> String {
        // Remove null bytes and control characters
        let sanitized = text.replacingOccurrences(of: "\0", with: "")
            .filter { !$0.isControlCharacter || $0.isNewline }
        
        // Trim whitespace
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func validateInput(_ text: String, maxLength: Int = 100_000) throws -> String {
        let sanitized = sanitizeText(text)
        
        guard !sanitized.isEmpty else {
            throw SlunkError.invalidInput("Text cannot be empty")
        }
        
        guard sanitized.count <= maxLength else {
            throw SlunkError.invalidInput("Text exceeds maximum length of \(maxLength) characters")
        }
        
        return sanitized
    }
}

extension Character {
    var isControlCharacter: Bool {
        let scalars = self.unicodeScalars
        return scalars.count == 1 && scalars.first!.properties.generalCategory == .control
    }
}

// MARK: - Resource Monitor

class ResourceMonitor {
    static let shared = ResourceMonitor()
    
    private let memoryMonitor = MemoryMonitor()
    private var activeOperations = 0
    private let operationQueue = DispatchQueue(label: "com.slunk.operations", attributes: .concurrent)
    private let maxConcurrentOperations = 50
    
    private init() {}
    
    func checkResources() throws {
        // Check memory pressure
        let pressure = memoryMonitor.getMemoryPressure()
        if pressure == .high {
            throw SlunkError.memoryPressureHigh
        }
        
        // Check concurrent operations
        let currentOps = operationQueue.sync { activeOperations }
        if currentOps >= maxConcurrentOperations {
            throw SlunkError.concurrencyLimitExceeded
        }
    }
    
    func trackOperation<T>(_ operation: () async throws -> T) async throws -> T {
        try checkResources()
        
        operationQueue.sync(flags: .barrier) {
            activeOperations += 1
        }
        
        defer {
            operationQueue.sync(flags: .barrier) {
                activeOperations -= 1
            }
        }
        
        return try await operation()
    }
}

// MARK: - Safe Wrapper

struct SafeOperation {
    static func perform<T>(
        context: String,
        operation: () async throws -> T
    ) async throws -> T {
        do {
            return try await ResourceMonitor.shared.trackOperation {
                try await operation()
            }
        } catch {
            ErrorLogger.shared.log(error, context: context)
            throw error
        }
    }
}

// MARK: - Production Extensions

extension SmartIngestionService {
    func safeIngestText(
        content: String,
        title: String,
        summary: String,
        sender: String? = nil,
        timestamp: Date? = nil
    ) async throws -> IngestionResult {
        try await SafeOperation.perform(context: "SmartIngestion") {
            let sanitizedContent = try InputSanitizer.validateInput(content)
            let sanitizedTitle = try InputSanitizer.validateInput(title, maxLength: 500)
            let sanitizedSummary = try InputSanitizer.validateInput(summary, maxLength: 5000)
            
            return try await self.ingestText(
                content: sanitizedContent,
                title: sanitizedTitle,
                summary: sanitizedSummary,
                sender: sender,
                timestamp: timestamp
            )
        }
    }
}

extension NaturalLanguageQueryEngine {
    func safeExecuteHybridSearch(
        _ query: ParsedQuery,
        limit: Int = 10
    ) async throws -> [QueryResult] {
        try await SafeOperation.perform(context: "QueryEngine") {
            guard limit > 0 && limit <= 100 else {
                throw SlunkError.invalidInput("Limit must be between 1 and 100")
            }
            
            return try await RetryHandler.retry {
                try await self.executeHybridSearch(query, limit: limit)
            }
        }
    }
}