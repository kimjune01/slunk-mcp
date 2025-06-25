import Foundation
import SQLiteVec

/// Database optimization and performance tuning utilities
class DatabaseOptimizer {
    
    // MARK: - Optimization Application
    
    func applyOptimizations(to schema: SQLiteVecSchema) async throws {
        guard let database = schema.database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        // Apply SQLite PRAGMA optimizations
        let optimizations = [
            // WAL mode for better concurrency
            "PRAGMA journal_mode = WAL",
            
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
        
        for pragma in optimizations {
            try await database.execute(pragma)
        }
    }
    
    func getCurrentSettings(from schema: SQLiteVecSchema) async throws -> [String: String] {
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
        
        for setting in settings {
            let query = "PRAGMA \(setting)"
            let rows = try await database.query(query)
            
            if let row = rows.first,
               let value = row[setting] {
                results[setting] = String(describing: value)
            }
        }
        
        return results
    }
    
    // MARK: - Query Analysis
    
    
    // MARK: - Database Maintenance
    
    func performVacuum(on schema: SQLiteVecSchema) async throws {
        guard let database = schema.database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        // VACUUM reclaims unused space and defragments the database
        try await database.execute("VACUUM")
    }
    
    func performAnalyze(on schema: SQLiteVecSchema) async throws {
        guard let database = schema.database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        // ANALYZE updates statistics for the query optimizer
        try await database.execute("ANALYZE")
    }
    
    func optimizeIndexes(on schema: SQLiteVecSchema) async throws {
        guard let database = schema.database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        // Create optimized indexes for common query patterns
        let indexQueries = [
            // Temporal queries
            "CREATE INDEX IF NOT EXISTS idx_summaries_timestamp ON text_summaries(timestamp)",
            
            // Sender queries  
            "CREATE INDEX IF NOT EXISTS idx_summaries_sender ON text_summaries(sender)",
            
            // Composite index for temporal + sender queries
            "CREATE INDEX IF NOT EXISTS idx_summaries_timestamp_sender ON text_summaries(timestamp, sender)",
            
            // Keywords JSON index (if supported)
            "CREATE INDEX IF NOT EXISTS idx_summaries_keywords ON text_summaries(keywords)",
            
            // Title and summary text indexes for keyword searches
            "CREATE INDEX IF NOT EXISTS idx_summaries_title ON text_summaries(title)",
            "CREATE INDEX IF NOT EXISTS idx_summaries_summary ON text_summaries(summary)"
        ]
        
        for indexQuery in indexQueries {
            do {
                try await database.execute(indexQuery)
            } catch {
                // Some indexes might already exist or not be supported
                print("Index creation skipped: \(error.localizedDescription)")
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

extension SQLiteVecSchema {
    func getDatabaseSize() async throws -> UInt64 {
        guard let database = database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        let query = "SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()"
        let rows = try await database.query(query)
        
        if let row = rows.first,
           let size = row["size"] as? Int64 {
            return UInt64(size)
        }
        
        return 0
    }
    
    func clearAllData() async throws {
        guard let database = database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        // Clear all tables while preserving schema
        try await database.execute("DELETE FROM text_summaries")
        try await database.execute("DELETE FROM summary_embeddings")
    }
    
    func getTableStatistics() async throws -> [String: TableStatistics] {
        guard let database = database else {
            throw DatabaseOptimizerError.databaseNotAvailable
        }
        
        var stats: [String: TableStatistics] = [:]
        
        let tables = ["text_summaries", "summary_embeddings"]
        
        for table in tables {
            let countQuery = "SELECT COUNT(*) as count FROM \(table)"
            let countRows = try await database.query(countQuery)
            
            let count = countRows.first?["count"] as? Int ?? 0
            
            stats[table] = TableStatistics(
                name: table,
                rowCount: count,
                estimatedSize: count * 1000 // Rough estimate
            )
        }
        
        return stats
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