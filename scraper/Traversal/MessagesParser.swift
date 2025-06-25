import ApplicationServices
import AsyncAlgorithms
import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

actor MessagesParser: CustomParser {
    public let parsedApp: ParseableApp = .messages

    private lazy var monitoringService = MonitoringService()
    public init() {}

    func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        let element = params.accessWindow
        var conversationSummaries: [ConversationSummary] = []
        var activeConversation: Conversation?

        if deadline.hasPassed { throw AccessError.timeout }
        
        let sequence = ElementDepthFirstSequence(
            element: element,
            deadline: deadline
        )
        
        for try await item in sequence {
            if deadline.hasPassed { break }
            
            let current = item
            
            if let role = try await current.element.getAttributeValue(.role) as? Role {
                switch role {
                case .group:
                    if let description = try await current.element.getAttributeValue(.description) as? String {
                        switch description {
                        case "Conversations":
                            conversationSummaries = await processConversationsList(
                                current.element,
                                stackItem: current,
                                deadline: deadline
                            )
                        case "Messages":
                            activeConversation?.messages = try await processMessagesList(
                                current.element,
                                stackItem: current,
                                deadline: deadline
                            )
                        default:
                            break
                        }
                    }
                case .popUpButton:
                    // This is likely the active conversation header
                    if let description = try await current.element.getAttributeValue(.description) as? String {
                        activeConversation = .init(app: parsedApp.title, channel: description, messages: [])
                    }
                default:
                    break
                }
            }
        }
        
        return ParseResult(conversationSummaries: conversationSummaries, activeConversation: activeConversation)
    }

    private func parseMessage(_ description: String) -> ConversationSummary? {
        let parts = description.split(separator: ",", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        let sender = String(parts[0])
        var remaining = String(parts[1]).trimmingCharacters(in: .whitespaces)

        let isUnread = remaining.hasPrefix("Unread,")
        if isUnread {
            remaining = remaining.dropFirst(7).trimmingCharacters(in: .whitespaces)
        }

        if let lastCommaIndex = remaining.lastIndex(of: ",") {
            let message = remaining[..<lastCommaIndex].trimmingCharacters(in: .whitespaces)
            let messageTime = remaining[remaining.index(after: lastCommaIndex)...].trimmingCharacters(in: .whitespaces)
            return ConversationSummary(
                app: parsedApp.title,
                sender: sender,
                lastMessage: String(message),
                lastMessageTime: String(messageTime),
                unread: isUnread
            )
        } else {
            return ConversationSummary(
                app: parsedApp.title,
                sender: sender,
                lastMessage: remaining,
                lastMessageTime: nil,
                unread: isUnread
            )
        }
    }

    private func processConversationsList(
        _ element: ElementProtocol,
        stackItem: StackItem,
        deadline: Deadline
    ) async -> [ConversationSummary] {
        do {
            return try await (stackItem.element.getChildren() ?? [])
                .async
                .prefix(while: { _ in !deadline.hasPassed })
                .filter({ await $0.has(role: .staticText) })
                .compactMap({ try await $0.getAttributeValue(.description) as? String })
                .compactMap({ await self.parseMessage($0) })
                .collect()
        } catch {
            Log.error("Error processing conversation", error: error)
            return []
        }
    }

    private func processMessagesList(
        _ element: ElementProtocol,
        stackItem: StackItem,
        deadline: Deadline
    ) async throws -> [Message] {
        var messages: [Message] = []
        var lastDateString: String?
        var lastDate: Date?
        guard let children = try await stackItem.element.getChildren() else { return [] }
        for child in children {
            //                if deadline.hasPassed { break }
            if await child.has(role: .group) {
                // Check for date separator
                let dateChildren = try await child.getChildren()
                if let lastChild = dateChildren?.last,
                   try await lastChild.getAttributeValue(.role) as? Role == .heading, // Unwrap the optional Role
                   let dateText = try await lastChild.getAttributeValue(.description) as? String,
                   let date = DateReformatter.reformatMessages(dateString: dateText) {
                    lastDateString = dateText
                    lastDate = date
                    continue
                }
            }

            if let description = try await child.getAttributeValue(.description) as? String {
                if let parsed = parseMessage(description) {
                    messages.append(
                        Message(
                            sender: parsed.sender,
                            content: parsed.lastMessage,
                            timestamp: lastDate,
                            messageType: "message",
                            timestring: lastDateString
                        )
                    )
                }
            }
        }

        return messages
    }
}
