import ApplicationServices
import AsyncAlgorithms
import Cocoa
import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

actor DiscordParser: CustomParser {
    public let parsedApp: ParseableApp = .discord

    static let MAX_CHILDREN = 200
    public init() {}

    func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        let conversations = try await processMessagesWindow(params.accessWindow, deadline: deadline)
        return ParseResult(conversationSummaries: [], activeConversations: conversations)
    }

    private func processMessagesWindow(_ element: ElementProtocol, deadline: Deadline) async throws -> [Conversation] {
        return try await ElementDepthFirstSequence(element: element)
            .map(\.element)
            .filter({ element in
                let isMessages = try (await element.getAttributeValue(.description) as? String ?? "")
                    .contains("Messages")
                let isList = await element.has(role: .list)
                return isMessages && isList
            })
            .compactMap({ try await self.conversation(in: $0) })
            .collect()
    }

    func conversation(in element: ElementProtocol) async throws -> Conversation? {
        var conversation = Conversation(app: parsedApp.title, channel: "", messages: [])

        if let description = try await element.getAttributeValue(.description) as? String,
           description.starts(with: "Messages in") {
            conversation.channel = String(description.dropFirst("Messages in".count))
        }

        conversation.messages = try await (element.getChildren() ?? [])
            .async
            .compactMap({ try await self.getMessageForElement($0) })
            .collect()

        return conversation
    }

    func getMessageForElement(_ element: ElementProtocol) async throws -> Message? {
        guard let header = try await getHeader(from: element) else { return nil }
        guard let dateString = try await getDate(from: header) else { return nil }
        guard let sender = try await getSender(from: header) else { return nil }
        guard let content = try await buildText(from: element) else { return nil }
        if sender.isEmpty { return nil }
        return Message(
            sender: sender,
            content: content,
            timestamp: DateReformatter.parseDiscordDateString(dateString),
            messageType: "message",
            timestring: dateString
        )
    }

    func getSender(from heading: ElementProtocol) async throws -> String? {
        guard await heading.has(role: .heading),
              let children = try await heading.getChildren(),
              let firstChild = children.first else { return nil }
        let parentElement = firstChild
        if let grandchildren = try await parentElement.getChildren(),
           let firstGrandchild = grandchildren.first {
            return try await firstGrandchild.getAttributeValue(.title) as? String
        }
        return nil
    }

    func getDate(from heading: ElementProtocol) async throws -> String? {
        guard await heading.has(role: .heading),
              let children = try await heading.getChildren(),
              let lastChild = children.last else { return nil }
        return try await lastChild.getAttributeValue(.description) as? String
    }

    func getHeader(from element: ElementProtocol) async throws -> ElementProtocol? {
        if await element.has(role: .heading) {
            return element
        }

        return try await element.getChildren()?
            .async
            .compactMap({ try await self.getHeader(from: $0) })
            .first(where: { _ in true })
    }

    func buildText(from element: ElementProtocol) async throws -> String? {
        guard await element.has(role: .staticText),
              let text = try await element.getValue() else {
            return nil
        }
        if await element.has(role: .heading) {
            return text
        }
        let childText = try await element.getChildren()?
            .async
            .compactMap({ try await self.buildText(from: $0) })
            .collect()
            .joined(separator: "") ?? ""

        return text + childText
    }
}
