import Foundation

// MARK: - Core Slack Data Models

public struct SlackMessage: Codable, Sendable {
    public let id: String
    public let timestamp: Date
    public let sender: String
    public let content: String
    public let threadId: String?
    public let messageType: MessageType
    public let metadata: MessageMetadata?
    
    public init(
        id: String = UUID().uuidString,
        timestamp: Date,
        sender: String,
        content: String,
        threadId: String? = nil,
        messageType: MessageType = .regular,
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sender = sender
        self.content = content
        self.threadId = threadId
        self.messageType = messageType
        self.metadata = metadata
    }
    
    public enum MessageType: String, Codable, CaseIterable, Sendable {
        case regular = "regular"
        case thread = "thread"
        case reply = "reply"
        case system = "system"
        case bot = "bot"
    }
    
    public struct MessageMetadata: Codable, Sendable {
        public let editedAt: Date?
        public let reactions: [String: Int]?    // emoji -> count mapping
        public let mentions: [String]?
        public let attachmentNames: [String]?   // file names only
        public let contentHash: String?         // for deduplication
        public let version: Int                 // for tracking edits
        
        public init(
            editedAt: Date? = nil,
            reactions: [String: Int]? = nil,
            mentions: [String]? = nil,
            attachmentNames: [String]? = nil,
            contentHash: String? = nil,
            version: Int = 1
        ) {
            self.editedAt = editedAt
            self.reactions = reactions
            self.mentions = mentions
            self.attachmentNames = attachmentNames
            self.contentHash = contentHash
            self.version = version
        }
    }
}

public struct SlackConversation: Codable, Sendable {
    public let id: String
    public let workspace: String
    public let channel: String
    public let channelType: ChannelType
    public let messages: [SlackMessage]
    public let capturedAt: Date
    public let windowTitle: String?
    public let context: ConversationContext?
    
    public init(
        id: String = UUID().uuidString,
        workspace: String,
        channel: String,
        channelType: ChannelType = .publicChannel,
        messages: [SlackMessage] = [],
        capturedAt: Date = Date(),
        windowTitle: String? = nil,
        context: ConversationContext? = nil
    ) {
        self.id = id
        self.workspace = workspace
        self.channel = channel
        self.channelType = channelType
        self.messages = messages
        self.capturedAt = capturedAt
        self.windowTitle = windowTitle
        self.context = context
    }
    
    public enum ChannelType: String, Codable, CaseIterable, Sendable {
        case publicChannel = "public"
        case privateChannel = "private"
        case directMessage = "dm"
        case groupDirectMessage = "group_dm"
        case thread = "thread"
    }
    
    public struct ConversationContext: Codable, Sendable {
        public let windowId: String?
        public let appVersion: String?
        public let workspaceId: String?
        public let channelId: String?
        
        public init(
            windowId: String? = nil,
            appVersion: String? = nil,
            workspaceId: String? = nil,
            channelId: String? = nil
        ) {
            self.windowId = windowId
            self.appVersion = appVersion
            self.workspaceId = workspaceId
            self.channelId = channelId
        }
    }
}

public struct SlackDocument: Codable, Sendable {
    public let id: String
    public let content: String
    public let source: DocumentSource
    public let metadata: DocumentMetadata
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        content: String,
        source: DocumentSource,
        metadata: DocumentMetadata,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.source = source
        self.metadata = metadata
        self.createdAt = createdAt
    }
    
    public struct DocumentSource: Codable, Sendable {
        public let type: SourceType
        public let workspace: String
        public let channel: String
        public let originalMessageId: String?
        public let threadId: String?
        
        public init(
            type: SourceType,
            workspace: String,
            channel: String,
            originalMessageId: String? = nil,
            threadId: String? = nil
        ) {
            self.type = type
            self.workspace = workspace
            self.channel = channel
            self.originalMessageId = originalMessageId
            self.threadId = threadId
        }
        
        public enum SourceType: String, Codable, CaseIterable, Sendable {
            case message = "message"
            case thread = "thread"
            case conversation = "conversation"
        }
    }
    
    public struct DocumentMetadata: Codable, Sendable {
        public let wordCount: Int
        public let characterCount: Int
        public let participantCount: Int
        public let timeSpan: TimeInterval?
        public let tags: [String]?
        
        public init(
            wordCount: Int,
            characterCount: Int,
            participantCount: Int,
            timeSpan: TimeInterval? = nil,
            tags: [String]? = nil
        ) {
            self.wordCount = wordCount
            self.characterCount = characterCount
            self.participantCount = participantCount
            self.timeSpan = timeSpan
            self.tags = tags
        }
    }
}

// MARK: - Protocol Conformances

extension SlackMessage: Identifiable {
    public typealias ID = String
}

extension SlackMessage: Timestamped {}

extension SlackMessage: Persistable {
    public var createdAt: Date { timestamp }
    public var updatedAt: Date { timestamp }
}

extension SlackMessage: SlackContentProcessable {}

extension SlackMessage: Validatable {
    public func validate() throws {
        guard !sender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SlackScraperError.invalidData("Message sender cannot be empty")
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SlackScraperError.invalidData("Message content cannot be empty")
        }
    }
}

extension SlackMessage: Deduplicatable {
    public var deduplicationKey: String {
        // Use timestamp as primary key (Slack's message ID format)
        return "\(timestamp.timeIntervalSince1970)"
    }
    
    public var contentHash: String {
        let hashContent = "\(content)\(sender)\(timestamp.timeIntervalSince1970)"
        return hashContent.sha256Hash
    }
    
    public func createUpdatedVersion(newContent: String, editedAt: Date) -> SlackMessage {
        let newVersion = (metadata?.version ?? 1) + 1
        let newMetadata = MessageMetadata(
            editedAt: editedAt,
            reactions: metadata?.reactions,
            mentions: metadata?.mentions,
            attachmentNames: metadata?.attachmentNames,
            contentHash: SlackMessage.generateContentHash(content: newContent, sender: sender, timestamp: timestamp),
            version: newVersion
        )
        
        return SlackMessage(
            id: id,
            timestamp: timestamp,
            sender: sender,
            content: newContent,
            threadId: threadId,
            messageType: messageType,
            metadata: newMetadata
        )
    }
    
    public func updateReactions(_ newReactions: [String: Int]) -> SlackMessage {
        let newMetadata = MessageMetadata(
            editedAt: metadata?.editedAt,
            reactions: newReactions,
            mentions: metadata?.mentions,
            attachmentNames: metadata?.attachmentNames,
            contentHash: metadata?.contentHash,
            version: metadata?.version ?? 1
        )
        
        return SlackMessage(
            id: id,
            timestamp: timestamp,
            sender: sender,
            content: content,
            threadId: threadId,
            messageType: messageType,
            metadata: newMetadata
        )
    }
    
    public static func generateContentHash(content: String, sender: String, timestamp: Date) -> String {
        let hashContent = "\(content)\(sender)\(timestamp.timeIntervalSince1970)"
        return hashContent.sha256Hash
    }
}

extension SlackConversation: Identifiable {
    public typealias ID = String
}

extension SlackConversation: Timestamped {
    public var timestamp: Date { capturedAt }
}

extension SlackConversation: Persistable {
    public var createdAt: Date { capturedAt }
    public var updatedAt: Date { capturedAt }
}

extension SlackConversation: SlackChannelScoped {}

extension SlackConversation: DocumentConvertible {
    public func toDocument() -> SlackDocument {
        let content = messages.map { message in
            "[\(ISO8601DateFormatter().string(from: message.timestamp))] \(message.sender): \(message.content)"
        }.joined(separator: "\n")
        
        let participants = Set(messages.map(\.sender))
        let timeSpan = messages.isEmpty ? 0 : 
            messages.max(by: { $0.timestamp < $1.timestamp })!.timestamp.timeIntervalSince(
                messages.min(by: { $0.timestamp < $1.timestamp })!.timestamp
            )
        
        return SlackDocument(
            content: content,
            source: SlackDocument.DocumentSource(
                type: .conversation,
                workspace: workspace,
                channel: channel
            ),
            metadata: SlackDocument.DocumentMetadata(
                wordCount: content.components(separatedBy: .whitespacesAndNewlines).count,
                characterCount: content.count,
                participantCount: participants.count,
                timeSpan: timeSpan
            )
        )
    }
}

extension SlackConversation: Validatable {
    public func validate() throws {
        guard !workspace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SlackScraperError.invalidData("Conversation workspace cannot be empty")
        }
        
        guard !channel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SlackScraperError.invalidData("Conversation channel cannot be empty")
        }
        
        // Validate all messages
        try messages.forEach { try $0.validate() }
    }
}

extension SlackConversation: Deduplicatable {
    public var deduplicationKey: String {
        let messageHashes = messages.map(\.deduplicationKey).joined(separator: "|")
        return "\(workspace):\(channel):\(messageHashes.hashValueForDeduplication)"
    }
}

extension SlackDocument: Identifiable {
    public typealias ID = String
}

extension SlackDocument: Timestamped {
    public var timestamp: Date { createdAt }
}

extension SlackDocument: Persistable {
    public var updatedAt: Date { createdAt }
}

extension SlackDocument: Validatable {
    public func validate() throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SlackScraperError.invalidData("Document content cannot be empty")
        }
        
        guard !source.workspace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SlackScraperError.invalidData("Document source workspace cannot be empty")
        }
        
        guard !source.channel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SlackScraperError.invalidData("Document source channel cannot be empty")
        }
    }
}

// MARK: - Helper Extensions

extension SlackConversation {
    public var summary: String {
        let messageCount = messages.count
        let participants = Set(messages.map(\.sender))
        let timeSpan = messages.isEmpty ? 0 : 
            messages.max(by: { $0.timestamp < $1.timestamp })!.timestamp.timeIntervalSince(
                messages.min(by: { $0.timestamp < $1.timestamp })!.timestamp
            )
        
        return """
            Conversation in #\(channel) (\(workspace))
            Messages: \(messageCount)
            Participants: \(participants.count)
            Duration: \(Int(timeSpan / 60)) minutes
            """
    }
    
    public var participantCount: Int {
        return Set(messages.map(\.sender)).count
    }
    
    public var messageCount: Int {
        return messages.count
    }
    
    public var timeSpan: TimeInterval {
        guard !messages.isEmpty else { return 0 }
        let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
        return sortedMessages.last!.timestamp.timeIntervalSince(sortedMessages.first!.timestamp)
    }
}