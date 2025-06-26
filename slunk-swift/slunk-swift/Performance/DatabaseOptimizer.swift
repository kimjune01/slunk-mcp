import Foundation
import GRDB

/// Database optimization and performance tuning utilities for Slack database
class DatabaseOptimizer {
    
    // MARK: - Optimization Application
    
    func applyOptimizations(to schema: SlackDatabaseSchema) async throws {
        guard let database = schema.database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        // Apply SQLite PRAGMA optimizations
        let optimizations = [
            // Note: WAL mode is already set during database initialization
            // to avoid lock conflicts, we don't set it again here
            
            // Increase cache size (negative value = KB, positive = pages)
            "PRAGMA cache_size = -64000", // 64MB cache
            
            // Faster synchronization (less safe but much faster)
            "PRAGMA synchronous = NORMAL",
            
            // Memory-mapped I/O for better performance
            "PRAGMA mmap_size = 268435456", // 256MB mmap
            
            // Optimize page size for better I/O
            "PRAGMA page_size = 4096",
            
            // Enable query optimization
            "PRAGMA optimize",
            
            // Increase temp store memory
            "PRAGMA temp_store = MEMORY",
            
            // Optimize automatic indexing
            "PRAGMA automatic_index = ON"
        ]
        
        try await database.write { db in
            for pragma in optimizations {
                try db.execute(sql: pragma)
            }
        }
    }
    
    func getCurrentSettings(from schema: SlackDatabaseSchema) async throws -> [String: String] {
        guard let database = schema.database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        let settings = [
            "journal_mode",
            "cache_size", 
            "synchronous",
            "mmap_size",
            "page_size",
            "temp_store",
            "automatic_index"
        ]
        
        var results: [String: String] = [:]
        
        try await database.read { db in
            for setting in settings {
                let query = "PRAGMA \(setting)"
                do {
                    let value = try String.fetchOne(db, sql: query) ?? "unknown"
                    results[setting] = value
                } catch {
                    results[setting] = "error"
                }
            }
        }
        
        return results
    }
    
    // MARK: - Query Analysis
    
    
    // MARK: - Database Maintenance
    
    func performVacuum(on schema: SlackDatabaseSchema) async throws {
        guard let database = schema.database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        // VACUUM reclaims unused space and defragments the database
        try await database.write { db in
            try db.execute(sql: "VACUUM")
        }
    }
    
    func performAnalyze(on schema: SlackDatabaseSchema) async throws {
        guard let database = schema.database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        // ANALYZE updates statistics for the query optimizer
        try await database.write { db in
            try db.execute(sql: "ANALYZE")
        }
    }
    
    func optimizeIndexes(on schema: SlackDatabaseSchema) async throws {
        guard let database = schema.database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        // Create optimized indexes for Slack message queries
        let indexQueries = [
            // Temporal queries
            "CREATE INDEX IF NOT EXISTS idx_messages_timestamp_opt ON slack_messages(timestamp DESC)",
            
            // Channel + timestamp composite for efficient channel browsing
            "CREATE INDEX IF NOT EXISTS idx_messages_channel_timestamp ON slack_messages(workspace, channel, timestamp DESC)",
            
            // Sender + timestamp for user activity queries
            "CREATE INDEX IF NOT EXISTS idx_messages_sender_timestamp ON slack_messages(sender, timestamp DESC)",
            
            // Thread optimization
            "CREATE INDEX IF NOT EXISTS idx_messages_thread_timestamp ON slack_messages(thread_ts, timestamp ASC)",
            
            // Content hash for deduplication queries
            "CREATE INDEX IF NOT EXISTS idx_messages_content_hash_workspace ON slack_messages(content_hash, workspace)",
            
            // Full-text search index
            "CREATE INDEX IF NOT EXISTS idx_messages_content_text ON slack_messages(content)"
        ]
        
        try await database.write { db in
            for indexQuery in indexQueries {
                do {
                    try db.execute(sql: indexQuery)
                    Logger.shared.logDatabaseOperation("Created index: \(indexQuery)")
                } catch {
                    Logger.shared.logDatabaseError(error, context: "DatabaseOptimizer.optimizeIndexes")
                }
            }
        }
    }
}


// MARK: - Memory Monitor

class MemoryMonitor {
    func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    func getMemoryPressure() -> MemoryPressure {
        let usage = getCurrentMemoryUsage()
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let percentage = Double(usage) / Double(totalMemory)
        
        switch percentage {
        case 0..<0.5:
            return .low
        case 0.5..<0.8:
            return .moderate
        default:
            return .high
        }
    }
}

enum MemoryPressure {
    case low
    case moderate
    case high
}

// MARK: - Database Extensions

extension SlackDatabaseSchema {
    func clearAllData() async throws {
        guard let database = database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        // Clear all tables while preserving schema
        try await database.write { db in
            try db.execute(sql: "DELETE FROM slack_messages")
            try db.execute(sql: "DELETE FROM slack_reactions")
            try db.execute(sql: "DELETE FROM slack_message_embeddings")
            try db.execute(sql: "DELETE FROM ingestion_log")
        }
    }
    
    func getTableStatistics() async throws -> [String: TableStatistics] {
        guard let database = database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        return try await database.read { db in
            var stats: [String: TableStatistics] = [:]
            
            let tables = ["slack_messages", "slack_reactions", "slack_message_embeddings", "ingestion_log"]
            
            for table in tables {
                let countQuery = "SELECT COUNT(*) as count FROM \(table)"
                let count = try Int.fetchOne(db, sql: countQuery) ?? 0
                
                stats[table] = TableStatistics(
                    name: table,
                    rowCount: count,
                    estimatedSize: count * 1000 // Rough estimate
                )
            }
            
            return stats
        }
    }
}

// MARK: - Supporting Types

struct TableStatistics {
    let name: String
    let rowCount: Int
    let estimatedSize: Int
}

enum DatabaseOptimizerError: Error {
    case databaseNotAvailable
    case optimizationFailed(String)
    case analysisError(String)
}

extension DatabaseOptimizerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .databaseNotAvailable:
            return "Database is not available for optimization"
        case .optimizationFailed(let message):
            return "Database optimization failed: \(message)"
        case .analysisError(let message):
            return "Query analysis failed: \(message)"
        }
    }
}