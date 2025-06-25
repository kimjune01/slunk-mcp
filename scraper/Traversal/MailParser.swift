import ApplicationServices
import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

actor MailParser: CustomParser {
    public let parsedApp: ParseableApp = .mail

    public init() {}

    func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        let element = params.accessWindow
        let mailboxName = (try? await element.getLabel()?.split(separator: " – ").first).map({ String($0) })

        var conversationSummaries: [ConversationSummary] = []
        var activeConversations: [Conversation] = []

        if deadline.hasPassed { throw AccessError.timeout }
        for try await element in ElementDepthFirstSequence(element: element).map(\.element) {
            if deadline.hasPassed { break }

            let role = try await element.getAttributeValue(.role) as? Role
            switch role {
            case .table where try await element.getLabel() == "messages":
                try await conversationSummaries.append(contentsOf: getSummaries(element: element))
                continue
            case .scrollArea where try await element.getLabel() == "message content":
                try await activeConversations.append(contentsOf: getMessages(
                    mailboxName: mailboxName,
                    element: element
                ))
                continue
            default:
                break
            }
        }
        return ParseResult(conversationSummaries: conversationSummaries, activeConversations: activeConversations)
    }

    func getSummaries(element: ElementProtocol) async throws -> [ConversationSummary] {
        var addressString: String?
        var dateString: String?
        var subject: String?
        var summary: String?
        var summaries: [ConversationSummary] = []

        func finalizeAndAppend() {
            if let addressString, !addressString.isEmpty {
                summaries.append(
                    ConversationSummary(
                        app: parsedApp.title,
                        sender: addressString,
                        lastMessage: [subject, summary].compactMap({ $0 }).joined(separator: " "),
                        lastMessageTime: dateString,
                        unread: nil
                    )
                )
            }
        }

        for try await element in ElementDepthFirstSequence(element: element).map(\.element) {
            let identifier = try await element.getAttributeValue(.identifier) as? String

            let value = try await element.getValue()
            switch identifier {
            case "Mail.messageList.cell.view":
                finalizeAndAppend()
            case "Mail.messageList.cell.view.summaryLabel":
                summary = value
            case "Mail.messageList.cell.view.subjectLabel":
                subject = value
            case "Mail.messageList.cell.view.dateLabel":
                dateString = value
            case "Mail.messageList.cell.view.addressLabel":
                addressString = value
            default:
                break
            }
        }

        finalizeAndAppend()

        return summaries
    }

    func getMessages(mailboxName: String?, element: ElementProtocol) async throws -> [Conversation] {
        var sender: String?
        var dateString: String?
        var content: String?

        var messages: [Message] = []

        func finalizeAndAppend() {
            if let content, !content.isEmpty {
                messages.append(
                    Message(
                        sender: sender,
                        content: content,
                        timestamp: nil,
                        messageType: "message",
                        timestring: dateString
                    )
                )
            }
        }

        for try await element in ElementDepthFirstSequence(element: element).map(\.element) {
            let identifier = try await element.getAttributeValue(.identifier) as? String

            let value = try await element.getValue()
            switch identifier {
            case "message_view":
                finalizeAndAppend()
            case "_MAIL_MESSAGE_BODY":
                content = await flattenContents(element)
            case "message.header.content":
                // subject not used for now
                break
            case "message.timestamp":
                dateString = value
            case "message.from.0":
                sender = value
            default:
                break
            }
        }

        finalizeAndAppend()

        return [Conversation(app: parsedApp.title, channel: mailboxName ?? "unknown", messages: messages)]
    }
}

func flattenContents(_ element: ElementProtocol) async -> String {
    await ElementDepthFirstSequence(element: element).map(\.element)
        .map({
            let label = try? await $0.getLabel()
            let value = try? await $0.getValue()
            return [label, value]
                .compactMap({ $0 })
                .joined(separator: " ")
        })
        .reduce("") { $0 + "\n" + $1 }
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
