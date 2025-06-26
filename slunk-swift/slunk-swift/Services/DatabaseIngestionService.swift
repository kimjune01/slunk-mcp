import Foundation

/// Service responsible for ingesting Slack conversations into the database
@MainActor
public final class DatabaseIngestionService {
    
    public init() {
    }
    
    private func logInfo(_ message: String) {
        Logger.shared.logIngestionInfo(message)
    }
    
    private func logError(_ error: Error, context: String) {
        Logger.shared.logIngestionError(error, context: context)
    }
    
    /// Ingest a Slack conversation into the database
    public func ingestConversation(_ conversation: SlackConversation, to database: SlackDatabaseSchema) async {
        logInfo("🔧 Ingesting \(conversation.messages.count) messages to Slack database...")
        logInfo("📊 Database URL: \(database.databaseURL)")
        
        // Check if database is initialized
        if !database.isDatabaseOpen() {
            logInfo("❌ Database connection is not open - reinitializing...")
            do {
                try await database.initializeDatabase()
                logInfo("✅ Database reinitialized")
            } catch {
                logError(error, context: "DatabaseIngestionService.reinitializeDatabase")
                return
            }
        }
        
        var stats = IngestionStats()
        
        // Process each message
        for message in conversation.messages {
            do {
                let slackMessage = createSlackMessage(from: message, conversation: conversation)
                let result = try await database.processMessage(
                    slackMessage,
                    workspace: conversation.workspace,
                    channel: conversation.channel
                )
                
                updateStats(&stats, for: result)
                
            } catch {
                stats.errors += 1
                logError(error, context: "DatabaseIngestionService.processMessage")
            }
        }
        
        logInfo("✅ Database ingestion complete!")
        logInfo("📊 New: \(stats.newMessages), Updates: \(stats.updates), Duplicates: \(stats.duplicates), Errors: \(stats.errors)")
        
        // Save ingestion checkpoint
        saveIngestionCheckpoint(for: conversation)
    }
    
    private func createSlackMessage(from message: SlackMessage, conversation: SlackConversation) -> SlackMessage {
        // Message is already a SlackMessage, but we may need to ensure it has the right channel
        // if it doesn't match the conversation channel
        if message.channel != conversation.channel {
            return SlackMessage(
                id: message.id,
                timestamp: message.timestamp,
                sender: message.sender,
                content: message.content,
                channel: conversation.channel,
                threadId: message.threadId,
                messageType: message.messageType,
                metadata: message.metadata
            )
        }
        return message
    }
    
    private func updateStats(_ stats: inout IngestionStats, for result: DeduplicationResult) {
        switch result {
        case .new(let messageId):
            stats.newMessages += 1
            stats.totalProcessed += 1
            logInfo("✅ New message: \(messageId)")
        case .duplicate:
            stats.duplicates += 1
            stats.totalProcessed += 1
        case .updated(let messageId):
            stats.updates += 1
            stats.totalProcessed += 1
            logInfo("📝 Updated existing message: \(messageId)")
        case .reactionsUpdated(let messageId):
            stats.reactionUpdates += 1
            logInfo("🙂 Updated reactions: \(messageId)")
        }
    }
    
    private func saveIngestionCheckpoint(for conversation: SlackConversation) {
        UserDefaults.standard.set(Date(), forKey: "SlunkLastIngestionTime")
        UserDefaults.standard.set(conversation.workspace, forKey: "SlunkLastIngestionWorkspace")
        UserDefaults.standard.set(conversation.channel, forKey: "SlunkLastIngestionChannel")
    }
    
    private struct IngestionStats {
        var totalProcessed = 0
        var newMessages = 0
        var updates = 0
        var duplicates = 0
        var reactionUpdates = 0
        var errors = 0
    }
}