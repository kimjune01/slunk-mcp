import Foundation
import NaturalLanguage

// MARK: - Supporting Types

public struct ThreadContext {
    public let threadId: String
    public let parentMessage: SlackMessage?
    public let recentMessages: [SlackMessage]
    public let totalMessageCount: Int
    
    public init(threadId: String, parentMessage: SlackMessage?, recentMessages: [SlackMessage], totalMessageCount: Int) {
        self.threadId = threadId
        self.parentMessage = parentMessage
        self.recentMessages = recentMessages
        self.totalMessageCount = totalMessageCount
    }
}

public struct ConversationChunk {
    public let id: String
    public let topic: String
    public let messages: [SlackMessage]
    public let summary: String
    public let timeRange: DateRange
    public let participants: [String]
    
    public struct DateRange {
        public let start: Date
        public let end: Date
        
        public init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
    }
    
    public init(id: String, topic: String, messages: [SlackMessage], summary: String, timeRange: DateRange, participants: [String]) {
        self.id = id
        self.topic = topic
        self.messages = messages
        self.summary = summary
        self.timeRange = timeRange
        self.participants = participants
    }
}

/// Context enhancement service for Slack messages, solving the short message problem.
///
/// MessageContextualizer transforms short, ambiguous messages (like emoji and abbreviations) 
/// into contextually meaningful text before embedding generation. This dramatically improves
/// semantic search accuracy for typical Slack conversations.
///
/// Core Capabilities:
/// - **Thread Context Enhancement**: Builds meaning from conversation history
/// - **Short Message Interpretation**: Translates emoji and abbreviations with context
/// - **Channel Context Mapping**: Applies topic-specific meaning to messages
/// - **Conversation Chunking**: Groups related messages for improved search
///
/// Example Transformations:
/// - "👍" in deployment thread → "deployment approval confirmation"
/// - "LGTM" in code review → "code review approval - looks good to me"
/// - "🚨" in incident channel → "urgent incident alert requiring attention"
public actor MessageContextualizer {
    private let embeddingService: EmbeddingService
    
    // MARK: - Configuration Constants
    
    /// Time window for grouping related messages into conversation chunks
    private static let defaultChunkTimeWindow: TimeInterval = 600 // 10 minutes
    
    /// Maximum number of messages per conversation chunk
    private static let maxChunkSize = 20
    
    /// Character threshold for considering a message "short" and needing context enhancement
    private static let shortMessageThreshold = 10
    
    /// Minimum keyword length for topic extraction
    private static let minKeywordLength = 2
    
    /// Time threshold for "recent" context (1 hour)
    private static let recentTimeThreshold: TimeInterval = 3600
    
    public init(embeddingService: EmbeddingService) {
        self.embeddingService = embeddingService
    }
    
    // MARK: - Thread Context Enhancement
    
    public func enhanceWithThreadContext(message: SlackMessage) async -> String {
        guard let threadId = message.threadId else { 
            return enhanceWithChannelContext(message: message)
        }
        
        // Get thread messages (this would need database access)
        let threadMessages = await getThreadMessages(threadId: threadId)
        let parentMessage = threadMessages.first?.content ?? ""
        let recentContext = threadMessages.suffix(3).map(\.content).joined(separator: " ")
        
        return """
        Thread context: \(parentMessage)
        Recent: \(recentContext)
        Current: \(message.content)
        Channel: \(getChannelTopic(for: message.channel))
        """
    }
    
    public func enhanceWithChannelContext(message: SlackMessage) -> String {
        let channelTopic = getChannelTopic(for: message.channel)
        let timeContext = getTimeContext(for: message.timestamp)
        
        return """
        Channel: \(channelTopic)
        Time: \(timeContext)
        Sender: \(message.sender)
        Content: \(message.content)
        """
    }
    
    private func getChannelTopic(for channel: String) -> String {
        // Map common channel patterns to topics
        let channelTopics: [String: String] = [
            "general": "General team discussions and announcements",
            "engineering": "Software development and technical discussions",
            "bugs": "Bug reports and issue tracking",
            "api": "API development and integration",
            "deployment": "Deployment discussions and releases",
            "standup": "Daily standup meetings and updates",
            "random": "Casual conversations and non-work topics"
        ]
        
        // Check for exact match first
        if let topic = channelTopics[channel.lowercased()] {
            return topic
        }
        
        // Check for partial matches
        for (key, topic) in channelTopics {
            if channel.lowercased().contains(key) {
                return topic
            }
        }
        
        return "Team discussions in #\(channel)"
    }
    
    private func getTimeContext(for timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let now = Date()
        let timeDiff = now.timeIntervalSince(timestamp)
        
        if timeDiff < Self.recentTimeThreshold {
            return "Recent message (\(Int(timeDiff / 60)) minutes ago)"
        } else if timeDiff < 86400 { // Less than 1 day
            return "Today (\(Int(timeDiff / Self.recentTimeThreshold)) hours ago)"
        } else if timeDiff < 604800 { // Less than 1 week
            return "This week (\(Int(timeDiff / 86400)) days ago)"
        } else {
            return "Older message (\(formatter.string(from: timestamp)))"
        }
    }
    
    // MARK: - Contextual Meaning Extraction
    
    public func extractContextualMeaning(
        from message: SlackMessage, 
        threadContext: ThreadContext? = nil
    ) async -> String? {
        // Handle emoji and short responses
        if isShortResponse(message.content) {
            return await interpretShortResponse(
                message: message, 
                threadContext: threadContext
            )
        }
        
        // Handle regular messages with context
        if let threadContext = threadContext {
            return await interpretInThreadContext(
                message: message, 
                threadContext: threadContext
            )
        }
        
        return nil
    }
    
    private func isShortResponse(_ content: String) -> Bool {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for emoji-only messages
        if cleanContent.unicodeScalars.allSatisfy({ $0.properties.isEmojiPresentation }) {
            return true
        }
        
        // Check for common short responses
        let shortResponses = ["lgtm", "sgtm", "yes", "no", "ok", "thanks", "done", "wip"]
        if shortResponses.contains(cleanContent.lowercased()) {
            return true
        }
        
        // Check for very short messages
        return cleanContent.count < Self.shortMessageThreshold
    }
    
    private func interpretShortResponse(
        message: SlackMessage, 
        threadContext: ThreadContext?
    ) async -> String? {
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Emoji interpretations
        let emojiMeanings: [String: String] = [
            "👍": "approval, agreement, or acknowledgment",
            "👎": "disapproval or disagreement", 
            "✅": "completion, confirmation, or approval",
            "❌": "rejection, cancellation, or error",
            "🚨": "urgent, alert, or critical issue",
            "🔥": "urgent, critical, or high priority",
            "💯": "complete agreement or strong approval",
            "😂": "humorous response or amusement",
            "🤔": "thinking, considering, or questioning",
            "💪": "confidence, strength, or readiness"
        ]
        
        if let meaning = emojiMeanings[content] {
            if let context = threadContext?.parentMessage?.content {
                return "\(meaning) in response to: \(context)"
            }
            return meaning
        }
        
        // Text abbreviation interpretations
        let textMeanings: [String: String] = [
            "lgtm": "looks good to me - approval",
            "sgtm": "sounds good to me - agreement", 
            "wip": "work in progress",
            "eta": "estimated time of arrival",
            "fyi": "for your information",
            "tl;dr": "too long; didn't read - summary request"
        ]
        
        if let meaning = textMeanings[content.lowercased()] {
            return meaning
        }
        
        // Generic short response with context
        if let context = threadContext?.parentMessage?.content {
            return "Short response '\(content)' to: \(context)"
        }
        
        return nil
    }
    
    private func interpretInThreadContext(
        message: SlackMessage, 
        threadContext: ThreadContext
    ) async -> String? {
        guard let parentContent = threadContext.parentMessage?.content else { return nil }
        
        let recentContext = threadContext.recentMessages.suffix(3)
            .map(\.content)
            .joined(separator: "; ")
        
        return """
        Response in thread about: \(parentContent)
        Recent context: \(recentContext)
        Current message: \(message.content)
        """
    }
    
    // MARK: - Conversation Chunking
    
    public func createConversationChunks(
        from messages: [SlackMessage], 
        timeWindow: TimeInterval = Self.defaultChunkTimeWindow
    ) async -> [ConversationChunk] {
        let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
        var chunks: [ConversationChunk] = []
        var currentChunk: [SlackMessage] = []
        var lastTimestamp: Date?
        
        for message in sortedMessages {
            let shouldStartNewChunk = shouldStartNewChunk(
                message: message,
                lastTimestamp: lastTimestamp,
                timeWindow: timeWindow,
                currentChunk: currentChunk
            )
            
            if shouldStartNewChunk && !currentChunk.isEmpty {
                let chunk = createChunk(from: currentChunk)
                chunks.append(chunk)
                currentChunk = []
            }
            
            currentChunk.append(message)
            lastTimestamp = message.timestamp
        }
        
        // Don't forget the last chunk
        if !currentChunk.isEmpty {
            let chunk = createChunk(from: currentChunk)
            chunks.append(chunk)
        }
        
        return chunks
    }
    
    private func shouldStartNewChunk(
        message: SlackMessage,
        lastTimestamp: Date?,
        timeWindow: TimeInterval,
        currentChunk: [SlackMessage]
    ) -> Bool {
        guard let lastTimestamp = lastTimestamp else { return false }
        
        // Time-based chunking: if more than timeWindow since last message
        if message.timestamp.timeIntervalSince(lastTimestamp) > timeWindow {
            return true
        }
        
        // Topic-based chunking: detect topic shifts
        if currentChunk.count > 3 {
            let recentTopics = extractTopics(from: Array(currentChunk.suffix(3)))
            let currentTopic = extractTopic(from: message)
            
            if !recentTopics.contains(currentTopic) && currentTopic != "general" {
                return true
            }
        }
        
        // Size-based chunking: limit chunk size
        return currentChunk.count >= Self.maxChunkSize
    }
    
    private func createChunk(from messages: [SlackMessage]) -> ConversationChunk {
        let participants = Set(messages.map(\.sender))
        let topic = generateChunkTopic(from: messages)
        let summary = generateChunkSummary(from: messages)
        
        let startTime = messages.min(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date()
        let endTime = messages.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date()
        
        return ConversationChunk(
            id: "chunk_\(UUID().uuidString.prefix(8))",
            topic: topic,
            messages: messages,
            summary: summary,
            timeRange: ConversationChunk.DateRange(start: startTime, end: endTime),
            participants: Array(participants)
        )
    }
    
    private func generateChunkTopic(from messages: [SlackMessage]) -> String {
        // Extract keywords from all messages
        let allContent = messages.map(\.content).joined(separator: " ")
        let keywords = extractKeywords(from: allContent)
        
        // Use most frequent meaningful keywords
        let meaningfulKeywords = keywords.prefix(3).joined(separator: ", ")
        
        if meaningfulKeywords.isEmpty {
            return "General discussion"
        }
        
        return meaningfulKeywords
    }
    
    private func generateChunkSummary(from messages: [SlackMessage]) -> String {
        let messageCount = messages.count
        let participants = Set(messages.map(\.sender))
        let timeSpan = messages.last?.timestamp.timeIntervalSince(messages.first?.timestamp ?? Date()) ?? 0
        
        let topic = generateChunkTopic(from: messages)
        
        return """
        \(messageCount) messages about \(topic) with \(participants.count) participants \
        over \(Int(timeSpan / 60)) minutes
        """
    }
    
    private func extractKeywords(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = text
        
        var keywords: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if let tag = tag, 
               [.noun, .verb, .adjective].contains(tag) {
                let (lemmaTag, _) = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lemma)
                if let lemma = lemmaTag?.rawValue {
                    keywords.append(lemma.lowercased())
                }
            }
            return true
        }
        
        // Remove common words and return top keywords
        let stopWords = Set(["the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"])
        let meaningfulKeywords = keywords.filter { !stopWords.contains($0) && $0.count > Self.minKeywordLength }
        
        return Array(Set(meaningfulKeywords)).sorted()
    }
    
    private func extractTopics(from messages: [SlackMessage]) -> Set<String> {
        var topics = Set<String>()
        
        for message in messages {
            let topic = extractTopic(from: message)
            topics.insert(topic)
        }
        
        return topics
    }
    
    private func extractTopic(from message: SlackMessage) -> String {
        let keywords = extractKeywords(from: message.content)
        return keywords.first ?? "general"
    }
    
    // MARK: - Helper Methods
    
    private func getThreadMessages(threadId: String) async -> [SlackMessage] {
        // This would require database access - returning empty for now
        // In real implementation, this would query the database for thread messages
        return []
    }
}

// MARK: - Enhanced Embedding Pipeline

extension MessageContextualizer {
    public func generateContextualEmbedding(for message: SlackMessage) async throws -> [Float] {
        let contextualContent = await enhanceWithThreadContext(message: message)
        return try await embeddingService.generateEmbedding(for: contextualContent)
    }
    
    public func generateChunkEmbedding(for chunk: ConversationChunk) async throws -> [Float] {
        let chunkContent = """
        Topic: \(chunk.topic)
        Summary: \(chunk.summary)
        Participants: \(chunk.participants.joined(separator: ", "))
        Key messages: \(chunk.messages.prefix(3).map(\.content).joined(separator: "; "))
        """
        
        return try await embeddingService.generateEmbedding(for: chunkContent)
    }
}