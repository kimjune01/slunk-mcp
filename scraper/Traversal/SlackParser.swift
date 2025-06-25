import ApplicationServices
import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

actor SlackParser: CustomParser {
    public let parsedApp: ParseableApp = .slack

    var lastSeenSender: String?
    var lastSeenTimestamp: String?

    public init() {}

    func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        Log.debug("SlackParser.parse() called", category: .controlFlow)
        Log.debug("==========================++===========================", category: .controlFlow)
        var result = ParseResult(activeConversations: [])

        let windowTitle = try await params.accessWindow.getAttributeValue(.title) as? String ?? ""

        guard let webAreaElement = try await params.accessWindow.findElement(
            matching: Matchers.hasAttribute(.role, equalTo: Role.webArea),
            deadline: deadline
        ) else {
            return result
        }

        let matchWorkspaceList = Matchers.hasAttribute(.description, equalTo: "Workspaces")

        if let workspaces = try await webAreaElement.findElement(
            matching: matchWorkspaceList,
            maxDepth: 4,
            deadline: deadline
        ) {
            result = try await processMainWindow(webAreaElement, workspaces: workspaces, deadline: deadline)
        } else {
            result = try await processChildWindow(webAreaElement, windowTitle: windowTitle, deadline: deadline)
        }

        return result
    }

    func processMainWindow(
        _ webAreaElement: ElementProtocol,
        workspaces: ElementProtocol,
        deadline: Deadline
    ) async throws -> ParseResult {
        var result = ParseResult(activeConversations: [])
        var team = ""

        if let selected = try await workspaces.findElement(matching: Matchers.hasAttribute(.selected, equalTo: true)) {
            team = try await selected.getAttributeValue(.title) as? String ?? ""
        }

        let matchWorkspaceList = Matchers.hasAttribute(.description, equalTo: "Workspaces")
        guard let workspaceWrapper = try await webAreaElement.findElement(
            matching: Matchers.hasClass("p-client_workspace_wrapper"),
            excludeMatchers: [matchWorkspaceList],
            deadline: deadline
        ) else {
            return result
        }

        let workspace = try await workspaceWrapper.getAttributeValue(.description) as? String ?? ""

        guard let viewContents = try await workspaceWrapper
            .findElement(matching: Matchers.hasClass("p-view_contents--primary")) else {
            return result
        }

        let viewContentsDescription = try await viewContents.getAttributeValue(.description) as? String

        if viewContentsDescription == "Threads" {
            return try await processThreadView(viewContents, workspace: workspace, deadline: deadline)
        }

        guard let contentList = try await viewContents.findElement(
            matching: Matchers.hasAttribute(.subrole, equalTo: Subrole.contentList),
            deadline: deadline
        ) else {
            return result
        }

        let channel = try await contentList.getAttributeValue(.description) as? String ?? ""
        let messages = try await (contentList.getChildren() ?? [])
            .async
            .prefix(while: { _ in !deadline.hasPassed })
            .compactMap({ child in
                try await self.processMessageUnit(child, deadline: deadline)
            })
            .collect()

        let fullChannelName = (team != "" ? team + ", " : "") +
            (workspace != "" ? workspace + ", " : "") +
            channel

        let conversation = Conversation(app: parsedApp.title, channel: fullChannelName, messages: messages)
        result.activeConversations?.append(conversation)

        return result
    }

    func processThreadView(
        _ viewContents: ElementProtocol,
        workspace: String,
        deadline: Deadline
    ) async throws -> ParseResult {
        var result = ParseResult(activeConversations: [])

        enum ThreadViewState {
            case searchingForHeader
            case processingMessages
        }

        guard let contentList = try await viewContents.findElement(
            matching: Matchers.hasAttribute(.subrole, equalTo: Subrole.contentList),
            deadline: deadline
        ) else {
            return result
        }

        guard let children = try await contentList.getChildren() else {
            return result
        }

        var state: ThreadViewState = .searchingForHeader
        var channelName = ""
        var participants = ""
        var messages: [Message] = []

        for child in children {
            let domId = try await child.getAttributeValue(.domIdentifier) as? String ?? ""

            switch state {
            case .searchingForHeader:
                guard domId.starts(with: "threads_view_heading") else {
                    continue
                }

                if let headerChildren = try await child.getChildren(), headerChildren.count >= 2 {
                    channelName = try await headerChildren[0].getValue() ?? ""
                    participants = try await headerChildren[1].getValue() ?? ""
                }
                state = .processingMessages

            case .processingMessages:
                if domId.starts(with: "threads_view_footer") {
                    let fullChannelName = (workspace != "" ? workspace + ", " : "") +
                        (channelName != "" ? channelName : "Thread") +
                        (participants != "" ? " with " + participants : "")

                    let conversation = Conversation(
                        app: parsedApp.title,
                        channel: fullChannelName,
                        messages: messages
                    )
                    result.activeConversations?.append(conversation)

                    state = .searchingForHeader
                    channelName = ""
                    participants = ""
                    messages = []
                } else {
                    if let message = try await processMessageUnit(child, deadline: deadline) {
                        messages.append(message)
                    }
                }
            }
        }

        if state == .processingMessages, !messages.isEmpty {
            let fullChannelName = (workspace != "" ? workspace + ", " : "") +
                (channelName != "" ? channelName : "Thread") +
                (participants != "" ? " with " + participants : "")

            let conversation = Conversation(
                app: parsedApp.title,
                channel: fullChannelName,
                messages: messages
            )
            result.activeConversations?.append(conversation)
        }

        return result
    }

    func workspaceFromWindow(_ windowTitle: String) async throws -> String {
        guard let endRange = windowTitle.range(of: " - Slack", options: .backwards) else {
            return ""
        }

        let beforeSlack = windowTitle[..<endRange.lowerBound]

        guard let lastDashRange = beforeSlack.range(of: " - ", options: .backwards) else {
            return ""
        }

        let workspaceStart = lastDashRange.upperBound
        return String(windowTitle[workspaceStart..<endRange.lowerBound])
    }

    func processChildWindow(
        _ webAreaElement: ElementProtocol,
        windowTitle: String,
        deadline: Deadline
    ) async throws -> ParseResult {
        var result = ParseResult(activeConversations: [])

        if windowTitle == "Slack" {
            guard try await webAreaElement.findElementWithClass("p-huddle_mini_panel") == nil else {
                return result
            }
        }

        if windowTitle.hasPrefix("Huddle") {
            processHuddleWindow(webAreaElement, windowTitle: windowTitle, deadline: deadline)
        }

        let workspace = try await workspaceFromWindow(windowTitle)

        guard let contentList = try await webAreaElement.findElement(
            matching: Matchers.hasAttribute(.subrole, equalTo: Subrole.contentList),
            deadline: deadline
        ) else {
            return result
        }

        let channel = try await contentList.getAttributeValue(.description) as? String ?? ""
        let messages = try await (contentList.getChildren() ?? [])
            .async
            .prefix(while: { _ in !deadline.hasPassed })
            .compactMap({ child in
                try await self.processMessageUnit(child, deadline: deadline)
            })
            .collect()

        let fullChannelName = (workspace != "" ? workspace + ", " : "") + channel
        let conversation = Conversation(app: parsedApp.title, channel: fullChannelName, messages: messages)
        result.activeConversations?.append(conversation)

        return result
    }

    private func processHuddleWindow(_ webAreaElement: ElementProtocol, windowTitle: String, deadline: Deadline) {
        Log.info("SlackParser found Huddle Window", category: .controlFlow)
    }

    private func processMessageUnit(_ element: ElementProtocol, deadline: Deadline) async throws -> Message? {
        let messageGroup = try await element.getAttributeValue(.childElements) as? [ElementProtocol]
        guard let firstGroup = messageGroup?.first,
              let roleDesc = try await firstGroup.getAttributeValue(.roleDescription) as? String,
              roleDesc == "message" else {
            return nil
        }

        let mainGroup = try await firstGroup.getAttributeValue(.childElements) as? [ElementProtocol]
        guard let firstMainGroup = mainGroup?.first else {
            return nil
        }

        // Extract message components
        let (sender, timestamp) = try await extractSenderAndTimestamp(firstMainGroup, deadline: deadline)
        let contentResult = await extractContentWithThread(firstMainGroup, deadline: deadline)

        if sender != nil {
            lastSeenSender = sender
        }

        if timestamp != nil {
            lastSeenTimestamp = timestamp
        }

        guard let sender = lastSeenSender,
              let timestamp = lastSeenTimestamp,
              let content = contentResult.content else {
            return nil
        }

        let messageType = contentResult.isThread ? "message, thread" :
            contentResult.isAttachment ? "attachment" : "message"

        // Convert relative timestamp to actual date
        let formattedTimestamp = DateReformatter.convertSlackTimestamp(timestamp)

        return Message(
            sender: sender,
            content: content,
            timestamp: formattedTimestamp,
            messageType: messageType,
            timestring: timestamp
        )
    }

    private struct ContentResult {
        let content: String?
        let isThread: Bool
        let isAttachment: Bool
        let threadInfo: [String]
    }

    private func extractContentWithThread(_ element: ElementProtocol, deadline: Deadline) async -> ContentResult {
        let removeZeroWidthSpaceTransform: ElementTransform<String> = { element in
            if let value = try? await element.getValue() {
                return value.replacingOccurrences(of: "\u{200B}", with: "")
            }
            return nil
        }

        let threadButtonCollector = TextCollector(transform: { element in
            try? await element.getAttributeValue(.title) as? String
        })
        let attachmentFlagCollector = BooleanFlagCollector(transform: { _ in true })
        let contentCollector = TextCollector(transform: removeZeroWidthSpaceTransform)
        let threadInfoCollector = TextCollector(transform: removeZeroWidthSpaceTransform)

        let rules: [RuleProtocol] = [
            Rule( // Thread button detection rule - collect thread titles
                matcher: Matchers.all([
                    Matchers.hasRole(.button),
                    Matchers.hasAttribute(.title, containsAny: ["reply", "replies"]),
                ]),
                collector: threadButtonCollector
            ),
            Rule( // Attachment button detection rule
                matcher: Matchers.all([
                    Matchers.hasRole(.button),
                    Matchers.hasAttribute(.description, equalTo: "Toggle file"),
                ]),
                collector: attachmentFlagCollector
            ),
            Rule( // Thread group detection rule
                matcher: Matchers.all([
                    Matchers.hasRole(.group),
                    Matchers.hasChild(matching: Matchers.hasAttribute(.value, substring: "Last reply")),
                ]),
                collector: threadInfoCollector
            ),
            Rule( // Rule for thread info text - only applies when thread flag is set
                matcher: Matchers.all([
                    Matchers.hasRole(.staticText),
                    Matchers.not(Matchers.hasAttribute(.value, equalTo: "\u{00A0}\u{00A0}")),
                    { _ in await threadButtonCollector.isEmpty() == false },
                ]),
                collector: threadInfoCollector
            ),
            Rule( // Rule for regular content text - only applies when thread flag is not set
                matcher: Matchers.all([
                    Matchers.hasRole(.staticText),
                    Matchers.not(Matchers.hasAttribute(.value, equalTo: "\u{00A0}\u{00A0}")),
                    { _ in await threadButtonCollector.isEmpty() },
                ]),
                collector: contentCollector
            ),
        ]
        // Traverse the element tree with our rules
        do {
            try await element.traverse(
                rules: rules,
                excludeMatchers: [Matchers.all([ // Exclude timestamp links
                    Matchers.hasRole(.link),
                    Matchers.hasAttribute(.description, substring: "at "),
                ])],
                deadline: deadline
            )

            let contentParts = await contentCollector.getItems()
            var threadInfo = await threadInfoCollector.getItems()
            let threadButtonTitles = await threadButtonCollector.getItems()
            threadInfo.append(contentsOf: threadButtonTitles)

            let mainContent = contentParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            let finalContent: String
            if !threadInfo.isEmpty {
                finalContent = "\(mainContent) (\(threadInfo.joined(separator: ", ")))"
            } else {
                finalContent = mainContent
            }

            return ContentResult(
                content: finalContent.isEmpty ? nil : finalContent,
                isThread: !threadInfo.isEmpty,
                isAttachment: await !attachmentFlagCollector.isEmpty(),
                threadInfo: threadInfo
            )
        } catch {
            Log.error("Error traversing element tree in extractContentWithThread", error: error)
            return ContentResult(content: nil, isThread: false, isAttachment: false, threadInfo: [])
        }
    }

    private func extractSenderAndTimestamp(
        _ element: ElementProtocol,
        deadline: Deadline
    ) async throws -> (String?, String?) {
        var sender: String?
        var timestamp: String?

        let children = try await element.getChildren() ?? []

        for child in children {
            if deadline.hasPassed { break }

            do {
                if await child.has(role: .button),
                   let title = try await child.getAttributeValue(.title) as? String {
                    sender = title
                } else if await child.has(role: .link),
                          let description = try await child.getAttributeValue(.description) as? String,
                          description.contains("at ") {
                    timestamp = description
                }
            } catch {
                continue
            }

            if sender != nil, timestamp != nil {
                break
            }
        }

        return (sender, timestamp)
    }

    private func extractContent(_ element: ElementProtocol, deadline: Deadline) async throws -> String? {
        var contentParts: [String] = []

        let children = try await element.getChildren() ?? []

        for child in children {
            if deadline.hasPassed { break }

            do {
                if await child.has(role: .staticText),
                   let value = try await child.getValue(),
                   value != "\u{00A0}\u{00A0}" { // Skip non-breaking spaces
                    contentParts.append(value)
                }
            } catch {
                continue
            }
        }

        let mainContent = contentParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return mainContent
    }
}
