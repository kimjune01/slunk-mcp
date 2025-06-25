import Foundation

/// Simple content processor with sensible defaults for Slack data
public struct SlackContentProcessor {
    
    // MARK: - Constants
    
    private static let maxMessageLength = 4000
    private static let maxConversationSize = 1000
    private static let deduplicationWindow: TimeInterval = 300 // 5 minutes
    
    // MARK: - Processing
    
    /// Process and validate a Slack message
    public static func processMessage(_ message: SlackMessage) -> SlackMessage? {
        // Basic validation
        guard !message.sender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        guard !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        // Filter out system messages if they're too short or noisy
        if message.messageType == .system && message.content.count < 10 {
            return nil
        }
        
        // Truncate overly long messages
        if message.content.count > maxMessageLength {
            let truncatedContent = String(message.content.prefix(maxMessageLength - 3)) + "..."
            return SlackMessage(
                id: message.id,
                timestamp: message.timestamp,
                sender: message.sender,
                content: truncatedContent,
                threadId: message.threadId,
                messageType: message.messageType,
                metadata: message.metadata
            )
        }
        
        return message
    }
    
    /// Process and validate a Slack conversation
    public static func processConversation(_ conversation: SlackConversation) -> SlackConversation? {
        // Basic validation
        guard !conversation.workspace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        guard !conversation.channel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        // Process messages
        let validMessages = conversation.messages.compactMap { processMessage($0) }
        
        // Skip conversations with no valid messages
        guard !validMessages.isEmpty else {
            return nil
        }
        
        // Limit conversation size
        let limitedMessages = Array(validMessages.prefix(maxConversationSize))
        
        return SlackConversation(
            id: conversation.id,
            workspace: conversation.workspace,
            channel: conversation.channel,
            channelType: conversation.channelType,
            messages: limitedMessages,
            capturedAt: conversation.capturedAt,
            windowTitle: conversation.windowTitle,
            context: conversation.context
        )
    }
    
    /// Create a document from a conversation
    public static func createDocument(from conversation: SlackConversation) -> SlackDocument {
        let document = conversation.toDocument()
        
        // Add processing timestamp to metadata
        let enhancedMetadata = SlackDocument.DocumentMetadata(
            wordCount: document.metadata.wordCount,
            characterCount: document.metadata.characterCount,
            participantCount: document.metadata.participantCount,
            timeSpan: document.metadata.timeSpan,
            tags: (document.metadata.tags ?? []) + ["processed", "slack-scraper"]
        )
        
        return SlackDocument(
            id: document.id,
            content: document.content,
            source: document.source,
            metadata: enhancedMetadata,
            createdAt: document.createdAt
        )
    }
}

// MARK: - Simple Deduplicator

public actor SlackContentDeduplicator {
    
    private var messageHashes: Set<String> = []
    private var conversationHashes: Set<String> = []
    private var lastCleanup = Date()
    
    // Clean up old entries every hour
    private static let cleanupInterval: TimeInterval = 3600
    
    /// Check if a message is a duplicate
    public func isDuplicate(message: SlackMessage) -> Bool {
        cleanupIfNeeded()
        
        let hash = message.deduplicationKey
        if messageHashes.contains(hash) {
            return true
        }
        
        messageHashes.insert(hash)
        return false
    }
    
    /// Check if a conversation is a duplicate
    public func isDuplicate(conversation: SlackConversation) -> Bool {
        cleanupIfNeeded()
        
        let hash = conversation.deduplicationKey
        if conversationHashes.contains(hash) {
            return true
        }
        
        conversationHashes.insert(hash)
        return false
    }
    
    /// Clear all stored hashes
    public func clear() {
        messageHashes.removeAll()
        conversationHashes.removeAll()
        lastCleanup = Date()
    }
    
    private func cleanupIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastCleanup) > Self.cleanupInterval {
            // Simple cleanup: clear everything periodically
            // In a production system, you might want more sophisticated cleanup
            clear()
        }
    }
}

// MARK: - Content Filter

public struct SlackContentFilter {
    
    /// Check if a message should be processed
    public static func shouldProcess(message: SlackMessage) -> Bool {
        // Skip empty messages
        let trimmedContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return false }
        
        // Skip very short messages (likely noise)
        guard trimmedContent.count >= 3 else { return false }
        
        // Skip messages that are just URLs or mentions
        if isOnlyUrlOrMention(trimmedContent) {
            return false
        }
        
        // Skip common automated messages
        if isAutomatedMessage(trimmedContent) {
            return false
        }
        
        return true
    }
    
    /// Check if a conversation should be processed
    public static func shouldProcess(conversation: SlackConversation) -> Bool {
        // Skip conversations with no messages
        guard !conversation.messages.isEmpty else { return false }
        
        // Skip conversations where none of the messages are worth processing
        let validMessages = conversation.messages.filter { shouldProcess(message: $0) }
        return !validMessages.isEmpty
    }
    
    private static func isOnlyUrlOrMention(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's just a URL
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            let components = trimmed.components(separatedBy: .whitespacesAndNewlines)
            if components.count == 1 {
                return true
            }
        }
        
        // Check if it's just mentions (starts with @)
        if trimmed.hasPrefix("@") && !trimmed.contains(" ") {
            return true
        }
        
        return false
    }
    
    private static func isAutomatedMessage(_ content: String) -> Bool {
        let lowercased = content.lowercased()
        
        // Common automated message patterns
        let automatedPatterns = [
            "joined the channel",
            "left the channel",
            "set the channel topic",
            "uploaded a file",
            "shared a file",
            "started a call",
            "ended a call"
        ]
        
        return automatedPatterns.contains { lowercased.contains($0) }
    }
}

// MARK: - Text Processor

public struct SlackTextProcessor {
    
    /// Clean and normalize text content
    public static func cleanText(_ text: String) -> String {
        var cleaned = text
        
        // Remove excessive whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Remove control characters
        cleaned = cleaned.components(separatedBy: .controlCharacters).joined()
        
        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    /// Extract keywords from text content
    public static func extractKeywords(from text: String, maxKeywords: Int = 10) -> [String] {
        let cleaned = cleanText(text)
        
        // Simple keyword extraction using word frequency
        let words = cleaned.lowercased()
            .components(separatedBy: .punctuationCharacters)
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .compactMap { word in
                let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.count >= 3 ? trimmed : nil
            }
        
        // Count word frequency
        var wordCounts: [String: Int] = [:]
        for word in words {
            wordCounts[word, default: 0] += 1
        }
        
        // Filter common stop words
        let stopWords = Set(["the", "and", "for", "are", "but", "not", "you", "all", "can", "had", "her", "was", "one", "our", "out", "day", "get", "has", "him", "his", "how", "its", "may", "new", "now", "old", "see", "two", "who", "boy", "did", "man", "men", "got", "let", "say", "she", "too", "use"])
        
        // Get top keywords (excluding stop words)
        let keywords = wordCounts
            .filter { !stopWords.contains($0.key) && $0.value > 1 }
            .sorted { $0.value > $1.value }
            .prefix(maxKeywords)
            .map { $0.key }
        
        return Array(keywords)
    }
    
    /// Create a summary of text content
    public static func createSummary(from text: String, maxLength: Int = 200) -> String {
        let cleaned = cleanText(text)
        
        if cleaned.count <= maxLength {
            return cleaned
        }
        
        // Simple summary: take first sentences up to maxLength
        let sentences = cleaned.components(separatedBy: ". ")
        var summary = ""
        
        for sentence in sentences {
            let potential = summary.isEmpty ? sentence : summary + ". " + sentence
            if potential.count <= maxLength - 3 {
                summary = potential
            } else {
                break
            }
        }
        
        if summary.isEmpty {
            summary = String(cleaned.prefix(maxLength - 3))
        }
        
        return summary + "..."
    }
}