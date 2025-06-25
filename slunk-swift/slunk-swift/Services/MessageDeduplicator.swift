import Foundation

// MARK: - Message Deduplication Service

class MessageDeduplicator {
    private let database: SlackDatabaseSchema
    
    init(database: SlackDatabaseSchema) {
        self.database = database
    }
    
    // MARK: - Public Interface
    
    func processConversation(_ conversation: SlackConversation) async throws -> IngestionStats {
        var stats = IngestionStats()
        
        for message in conversation.messages {
            let result = try await database.processMessage(
                message,
                workspace: conversation.workspace,
                channel: conversation.channel
            )
            
            switch result {
            case .new:
                stats.newMessages += 1
            case .duplicate:
                stats.duplicates += 1
            case .updated:
                stats.updates += 1
            case .reactionsUpdated:
                stats.reactionUpdates += 1
            }
            
            stats.totalProcessed += 1
        }
        
        // Log the ingestion session
        try await database.logIngestionSession(
            workspace: conversation.workspace,
            channel: conversation.channel,
            stats: stats
        )
        
        return stats
    }
    
    func processMessage(_ message: SlackMessage, workspace: String, channel: String) async throws -> DeduplicationResult {
        return try await database.processMessage(message, workspace: workspace, channel: channel)
    }
    
    // MARK: - Validation Helpers
    
    func validateMessage(_ message: SlackMessage) throws {
        try message.validate()
        
        // Additional Slack-specific validation
        guard !message.sender.isEmpty else {
            throw MessageDeduplicationError.invalidMessage("Message sender cannot be empty")
        }
        
        guard !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MessageDeduplicationError.invalidMessage("Message content cannot be empty")
        }
    }
    
    func validateConversation(_ conversation: SlackConversation) throws {
        try conversation.validate()
        
        guard !conversation.workspace.isEmpty else {
            throw MessageDeduplicationError.invalidConversation("Workspace cannot be empty")
        }
        
        guard !conversation.channel.isEmpty else {
            throw MessageDeduplicationError.invalidConversation("Channel cannot be empty")
        }
        
        // Validate all messages
        for message in conversation.messages {
            try validateMessage(message)
        }
    }
    
    // MARK: - Statistics and Reporting
    
    func getIngestionHistory(workspace: String, channel: String, limit: Int = 10) async throws -> [IngestionSessionInfo] {
        // This would query the ingestion_log table
        // Implementation would go here when we add query methods to SlackDatabaseSchema
        return []
    }
    
    func getDeduplicationStats(workspace: String, channel: String) async throws -> DeduplicationStats {
        // This would provide statistics about deduplication effectiveness
        return DeduplicationStats(
            totalMessages: 0,
            uniqueMessages: 0,
            duplicatesFound: 0,
            editsTracked: 0,
            reactionUpdates: 0
        )
    }
}

// MARK: - Supporting Types

struct IngestionSessionInfo {
    let sessionId: String
    let workspace: String
    let channel: String
    let ingestedAt: Date
    let messageCount: Int
    let newMessages: Int
    let updatedMessages: Int
    let duplicateMessages: Int
}

struct DeduplicationStats {
    let totalMessages: Int
    let uniqueMessages: Int
    let duplicatesFound: Int
    let editsTracked: Int
    let reactionUpdates: Int
    
    var deduplicationRate: Double {
        guard totalMessages > 0 else { return 0 }
        return Double(duplicatesFound) / Double(totalMessages)
    }
    
    var editRate: Double {
        guard uniqueMessages > 0 else { return 0 }
        return Double(editsTracked) / Double(uniqueMessages)
    }
}

enum MessageDeduplicationError: Error {
    case invalidMessage(String)
    case invalidConversation(String)
    case processingFailed(String)
    case databaseError(String)
}

extension MessageDeduplicationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidMessage(let message):
            return "Invalid message: \(message)"
        case .invalidConversation(let message):
            return "Invalid conversation: \(message)"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        }
    }
}