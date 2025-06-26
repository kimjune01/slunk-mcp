import Foundation
import os.log

// MARK: - Logger

class Logger {
    static let shared = Logger()
    
    // OS Log subsystem
    private let subsystem = Bundle.main.bundleIdentifier ?? "com.slunk"
    
    // Log categories
    private let databaseLog: OSLog
    private let queryLog: OSLog
    private let ingestionLog: OSLog
    private let performanceLog: OSLog
    private let errorLog: OSLog
    private let mcpLog: OSLog
    
    // File logger for production
    private let fileLogger: FileLogger?
    
    private init() {
        // Initialize OS logs
        databaseLog = OSLog(subsystem: subsystem, category: "Database")
        queryLog = OSLog(subsystem: subsystem, category: "Query")
        ingestionLog = OSLog(subsystem: subsystem, category: "Ingestion")
        performanceLog = OSLog(subsystem: subsystem, category: "Performance")
        errorLog = OSLog(subsystem: subsystem, category: "Error")
        mcpLog = OSLog(subsystem: subsystem, category: "MCP")
        
        // Initialize file logger for production
        if !Configuration.shared.isDebug {
            fileLogger = FileLogger()
        } else {
            fileLogger = nil
        }
    }
    
    // MARK: - Database Logging
    
    func logDatabaseOperation(_ message: String, type: OSLogType = .info) {
        os_log("%{public}@", log: databaseLog, type: type, message)
        fileLogger?.log(message, category: "Database", type: type)
    }
    
    func logDatabaseError(_ error: Error, context: String) {
        let message = "Database error in \(context): \(error.localizedDescription)"
        os_log("%{public}@", log: databaseLog, type: .error, message)
        fileLogger?.log(message, category: "Database", type: .error)
    }
    
    func logDatabaseCleanup(_ message: String, type: OSLogType = .info) {
        os_log("%{public}@", log: databaseLog, type: type, message)
        fileLogger?.log(message, category: "Database-Cleanup", type: type)
    }
    
    // MARK: - Query Logging
    
    func logQuery(_ query: String, resultCount: Int, duration: TimeInterval) {
        let message = "Query: '\(query)' returned \(resultCount) results in \(Int(duration * 1000))ms"
        os_log("%{public}@", log: queryLog, type: .info, message)
        fileLogger?.log(message, category: "Query", type: .info)
    }
    
    func logQueryError(_ error: Error, query: String) {
        let message = "Query error for '\(query)': \(error.localizedDescription)"
        os_log("%{public}@", log: queryLog, type: .error, message)
        fileLogger?.log(message, category: "Query", type: .error)
    }
    
    // MARK: - Ingestion Logging
    
    func logIngestion(title: String, keywords: Int, duration: TimeInterval) {
        let message = "Ingested '\(title)' with \(keywords) keywords in \(Int(duration * 1000))ms"
        os_log("%{public}@", log: ingestionLog, type: .info, message)
        fileLogger?.log(message, category: "Ingestion", type: .info)
    }
    
    func logIngestionError(_ error: Error, title: String) {
        let message = "Ingestion error for '\(title)': \(error.localizedDescription)"
        os_log("%{public}@", log: ingestionLog, type: .error, message)
        fileLogger?.log(message, category: "Ingestion", type: .error)
    }
    
    func logIngestionInfo(_ message: String) {
        os_log("%{public}@", log: ingestionLog, type: .info, message)
        fileLogger?.log(message, category: "Ingestion", type: .info)
    }
    
    func logIngestionError(_ error: Error, context: String) {
        let message = "Ingestion error in \(context): \(error.localizedDescription)"
        os_log("%{public}@", log: ingestionLog, type: .error, message)
        fileLogger?.log(message, category: "Ingestion", type: .error)
    }
    
    // MARK: - Performance Logging
    
    func logPerformanceMetric(operation: String, duration: TimeInterval, metadata: [String: Any]? = nil) {
        var message = "Performance: \(operation) completed in \(Int(duration * 1000))ms"
        if let metadata = metadata {
            let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            message += " [\(metadataString)]"
        }
        os_log("%{public}@", log: performanceLog, type: .info, message)
        fileLogger?.log(message, category: "Performance", type: .info)
    }
    
    func logMemoryWarning(usage: UInt64, pressure: MemoryPressure) {
        let message = "Memory warning: \(usage / 1_000_000)MB used, pressure: \(pressure)"
        os_log("%{public}@", log: performanceLog, type: .fault, message)
        fileLogger?.log(message, category: "Performance", type: .fault)
    }
    
    // MARK: - Error Logging
    
    func logError(_ error: Error, context: String, additionalInfo: [String: Any]? = nil) {
        var message = "Error in \(context): \(error.localizedDescription)"
        if let info = additionalInfo {
            let infoString = info.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            message += " [\(infoString)]"
        }
        os_log("%{public}@", log: errorLog, type: .error, message)
        fileLogger?.log(message, category: "Error", type: .error)
    }
    
    // MARK: - MCP Logging
    
    func logMCPRequest(method: String, params: [String: Any]?) {
        var message = "MCP Request: \(method)"
        if let params = params {
            message += " params: \(params)"
        }
        os_log("%{public}@", log: mcpLog, type: .info, message)
        fileLogger?.log(message, category: "MCP", type: .info)
    }
    
    func logMCPResponse(method: String, success: Bool, duration: TimeInterval) {
        let message = "MCP Response: \(method) \(success ? "succeeded" : "failed") in \(Int(duration * 1000))ms"
        os_log("%{public}@", log: mcpLog, type: success ? .info : .error, message)
        fileLogger?.log(message, category: "MCP", type: success ? .info : .error)
    }
    
    // MARK: - General Logging
    
    func logInfo(_ message: String) {
        os_log("%{public}@", log: OSLog.default, type: .info, message)
        fileLogger?.log(message, category: "General", type: .info)
    }
}

// MARK: - File Logger

private class FileLogger {
    private let logDirectory: URL
    private let dateFormatter: DateFormatter
    private let logQueue = DispatchQueue(label: "com.slunk.filelog", qos: .utility)
    private var currentLogFile: URL?
    private let maxLogSize: Int64 = 10_485_760 // 10MB
    private let maxLogFiles = 5
    
    init() {
        self.logDirectory = Configuration.shared.logDirectory
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Rotate logs on init
        rotateLogsIfNeeded()
    }
    
    func log(_ message: String, category: String, type: OSLogType) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = self.dateFormatter.string(from: Date())
            let level = self.logLevel(for: type)
            let logEntry = "[\(timestamp)] [\(level)] [\(category)] \(message)\n"
            
            self.writeToLog(logEntry)
        }
    }
    
    private func writeToLog(_ entry: String) {
        let logFile = currentLogFile ?? createNewLogFile()
        
        guard let data = entry.data(using: .utf8) else { return }
        
        do {
            if FileManager.default.fileExists(atPath: logFile.path) {
                let handle = try FileHandle(forWritingTo: logFile)
                defer { 
                    try? handle.close()
                }
                handle.seekToEndOfFile()
                handle.write(data)
                
                // Check if rotation needed
                rotateLogsIfNeeded()
            } else {
                try data.write(to: logFile)
            }
        } catch {
            print("Failed to write to log: \(error)")
        }
    }
    
    private func createNewLogFile() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let fileName = "slunk_\(formatter.string(from: Date())).log"
        let logFile = logDirectory.appendingPathComponent(fileName)
        currentLogFile = logFile
        return logFile
    }
    
    private func rotateLogsIfNeeded() {
        guard let currentLog = currentLogFile else { return }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: currentLog.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if fileSize > maxLogSize {
                currentLogFile = createNewLogFile()
                cleanOldLogs()
            }
        } catch {
            // File doesn't exist, create new one
            currentLogFile = createNewLogFile()
        }
    }
    
    private func cleanOldLogs() {
        do {
            let logFiles = try FileManager.default.contentsOfDirectory(
                at: logDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            ).filter { $0.pathExtension == "log" }
            
            if logFiles.count > maxLogFiles {
                let sortedFiles = logFiles.sorted { file1, file2 in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 < date2
                }
                
                let filesToDelete = sortedFiles.dropLast(maxLogFiles)
                for file in filesToDelete {
                    try FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            print("Failed to clean old logs: \(error)")
        }
    }
    
    private func logLevel(for type: OSLogType) -> String {
        switch type {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .error: return "ERROR"
        case .fault: return "FAULT"
        default: return "DEFAULT"
        }
    }
}

// MARK: - Performance Timer

class PerformanceTimer {
    private let startTime: Date
    private let operation: String
    private var metadata: [String: Any] = [:]
    
    init(operation: String) {
        self.startTime = Date()
        self.operation = operation
    }
    
    func addMetadata(key: String, value: Any) {
        metadata[key] = value
    }
    
    func stop() {
        let duration = Date().timeIntervalSince(startTime)
        Logger.shared.logPerformanceMetric(
            operation: operation,
            duration: duration,
            metadata: metadata
        )
    }
}

// MARK: - Global Debug Logging Functions

/// Print debug information only in DEBUG builds
/// This prevents debug logs from interfering with MCP JSON-RPC communication
func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}

/// Log an error to stderr (file handle 2) which doesn't interfere with stdout
func logError(_ message: String) {
    let errorHandle = FileHandle.standardError
    if let data = "\(message)\n".data(using: .utf8) {
        errorHandle.write(data)
    }
}