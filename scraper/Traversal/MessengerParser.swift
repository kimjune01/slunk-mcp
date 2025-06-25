import ApplicationServices
import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

actor MessengerParser: CustomParser {
    public let parsedApp: ParseableApp = .messenger

    private var currentData: Conversation?

    public init() {}

    func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        Log.debug(
            """
            MessengerParser.parse() called
            ==========================++===========================
            """,
            category: .controlFlow
        )
        try await processMessengerWindow(params.accessWindow, deadline: deadline)
        if let data = currentData {
            return ParseResult(activeConversations: [data])
        } else {
            Log.error("MessengerParser failed to parse")
            return .empty
        }
    }

    private struct CollectedMessage {
        let element: ElementProtocol
        let frame: Frame?
        let stackItem: StackItem
    }

    // MARK: - Data Structures

    struct Frame: Codable, Hashable {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat

        var leftSide: CGFloat { x }
        var rightSide: CGFloat { x + width }

        static func from(element: ElementProtocol) async -> Frame? {
            do {
                if let position: Point = try await element.getAttributeValue(.position) as? Point,
                   let size: Size = try await element.getAttributeValue(.size) as? Size {
                    return Frame(
                        x: position.x,
                        y: position.y,
                        width: size.width,
                        height: size.height
                    )
                }
            } catch {
                Log.error("Error getting frame from element", error: error)
                // Add more specific debug info
                let position: Point? = try? await element.getAttributeValue(.position) as? Point
                let size: Size? = try? await element.getAttributeValue(.size) as? Size
                Log.error("Position: \(String(describing: position))", error: error)
                Log.error("Size: \(String(describing: size))", error: error)
            }
            return nil
        }

        static func merge(_ frames: [Frame]) -> Frame? {
            guard !frames.isEmpty else { return nil }

            let left = frames.map { $0.x }.min()!
            let right = frames.map { $0.rightSide }.max()!
            let top = frames.map { $0.y }.min()!
            let bottom = frames.map { $0.y + $0.height }.max()!

            return Frame(
                x: left,
                y: top,
                width: right - left,
                height: bottom - top
            )
        }
    }

    struct ChatInfo {
        let name: String
        let isGroup: Bool
        let otherPerson: String?
    }

    struct MessageElement: Codable, Hashable {
        let role: String
        let identifier: String
        let description: String
        let value: String
        let depth: Int
        var sender: String?
        var frame: Frame?
        var timestamp: String? // Changed from Date? to String? for Codability

        enum CodingKeys: String, CodingKey {
            case role, identifier, description, value, depth, sender, timestamp
        }

        init(
            role: String,
            identifier: String,
            description: String,
            value: String,
            depth: Int,
            sender: String? = nil,
            frame: Frame? = nil,
            timestamp: Date? = nil
        ) {
            self.role = role
            self.identifier = identifier
            self.description = description
            self.value = value
            self.depth = depth
            self.sender = sender
            self.frame = frame
            // Convert Date to ISO8601 string if present
            self.timestamp = timestamp?.ISO8601Format()
        }
    }

    struct ParsedMessage: Codable, Hashable {
        var sender: String?
        var messageType: String
        var frame: Frame?
        var value: String?
        var count: Int?
        var timestamp: Date? = Date()
        var replyContext: String?
        var metadata: [String]?
        var rawElements: [MessageElement]?

        enum CodingKeys: String, CodingKey {
            case sender
            case messageType
            case value
            case count
            case timestamp
            case replyContext
            case metadata
            case rawElements
        }

        init(
            sender: String? = nil,
            messageType: String,
            frame: Frame? = nil,
            value: String? = nil,
            count: Int? = nil,
            timestamp: Date? = nil,
            replyContext: String? = nil,
            metadata: [String]? = nil,
            rawElements: [MessageElement]? = nil
        ) {
            self.sender = sender
            self.messageType = messageType
            self.frame = frame
            self.value = value
            self.count = count
            self.timestamp = timestamp
            self.replyContext = replyContext
            self.metadata = metadata
            self.rawElements = rawElements
        }

        func toVanillaMessage() -> Message {
            return Message(
                sender: sender,
                content: value,
                timestamp: timestamp,
                messageType: messageType,
                timestring: timestamp?.ISO8601Format()
            )
        }
    }

    // MARK: - Main Processing

    private func processMessengerWindow(_ element: ElementProtocol, deadline: Deadline) async throws {
        let chatInfo = await extractChatInfo(from: element)
        currentData = Conversation(
            app: parsedApp.title,
            channel: chatInfo.name,
            isGroup: chatInfo.isGroup,
            messages: []
        )

        let stack = [StackItem(element: element, path: [])]
        var processedStack = [(StackItem, ElementProtocol)]()

        try await collectRelevantElements(from: stack, into: &processedStack, deadline: deadline)

        if let messagesList = await findMessagesList(in: processedStack) {
            await processMessagesList(
                messagesList.0,
                element: messagesList.1,
                chatInfo: chatInfo,
                deadline: deadline
            )
        }
    }
    
    private func collectRelevantElements(from initialStack: [StackItem],
                                         into processed: inout [(StackItem, ElementProtocol)],
                                         deadline: Deadline) async throws {
        
        if deadline.hasPassed { throw AccessError.timeout }
        
        for itemStack in initialStack {
            let sequence = ElementDepthFirstSequence(
                element: itemStack.element,
                deadline: deadline
            )
            
            for try await item in sequence {
                if deadline.hasPassed { break }
                processed.append((item, item.element))
            }
        }
    }

    // MARK: - Main Processing

    private func processMessagesList(
        _ stackItem: StackItem,
        element: ElementProtocol,
        chatInfo: ChatInfo,
        deadline: Deadline
    ) async {
        Log.info("=== Starting processMessagesList ===", category: .controlFlow)

        // Get the frame of the messages list for sender determination
        let messagesListFrame = await Frame.from(element: element)
        Log.info("Messages List Frame: \(String(describing: messagesListFrame))", category: .controlFlow)

        // Collect all message elements first
        var collectedMessages: [CollectedMessage] = []

        do {
            if let children = try await stackItem.element.getChildren() {
                Log.info("Found \(children.count) children in messages list", category: .controlFlow)
                for (index, child) in children.enumerated() {
                    if deadline.hasPassed { break }

                    let childItem = StackItem(element: child, path: stackItem.path + [index])
                    let frame = await Frame.from(element: child)

                    if !(await shouldIgnoreElement(child)) {
                        collectedMessages.append(CollectedMessage(
                            element: child,
                            frame: frame,
                            stackItem: childItem
                        ))
                        // debugPrint("Added message \(index) to collected messages", .controlFlow)
                    }
                }
            }
        } catch {
            Log.error("Error getting children from messages list", error: error)
            return // Or handle the error in another way
        }

        Log.info("Collected \(collectedMessages.count) total messages before grouping", category: .controlFlow)

        // Group messages by Y coordinate
        let messageGroups = await groupMessagesByYCoordinate(collectedMessages)
        Log.info("Grouped into \(messageGroups.count) message groups", category: .controlFlow)
        // Process each group
        var messages: [ParsedMessage] = []
        var pendingSenderMessages: [ParsedMessage] = []
        var currentTimestamp: Date?
        var pendingReplyContext: String?

        for group in messageGroups {
            if deadline.hasPassed { break }

            // Check for reply context first
            if group.count == 1,
               let identifier = try? await group[0].element.getAttributeValue(.identifier) as? String,
               identifier == "reply_context_message",
               let description = try? await group[0].element.getAttributeValue(.description) as? String {
                pendingReplyContext = description
                continue
            }

            guard let parsedMessage = await parseMessageGroup(
                group,
                messagesListFrame: messagesListFrame,
                chatInfo: chatInfo
            ) else {
                continue
            }

            // Handle admin timestamp messages
            if parsedMessage.messageType == "Admin", let timestamp = parsedMessage.timestamp {
                if !pendingSenderMessages.isEmpty {
                    messages.append(contentsOf: pendingSenderMessages.map { msg in
                        var updatedMsg = msg
                        if let context = pendingReplyContext {
                            updatedMsg.replyContext = context
                        }
                        return updatedMsg
                    })
                    pendingSenderMessages.removeAll()
                    pendingReplyContext = nil
                }
                currentTimestamp = timestamp
                continue
            }

            // Skip unknown message types
            if parsedMessage.messageType == "Unknown" {
                // Check if this is a sender identifier element in a group chat
                if chatInfo.isGroup, group.count == 1,
                   let firstElement = group.first,
                   await isSenderIdentifierElement(firstElement.element) {
                    if let senderName = try? await firstElement.element.getAttributeValue(.description) as? String {
                        let updatedMessages = pendingSenderMessages.map { msg in
                            var updatedMsg = msg
                            updatedMsg.sender = senderName
                            if let context = pendingReplyContext {
                                updatedMsg.replyContext = context
                            }
                            return updatedMsg
                        }
                        messages.append(contentsOf: updatedMessages)
                        pendingSenderMessages.removeAll()
                        pendingReplyContext = nil
                    }
                    continue
                }
                continue
            }

            // Create updated message with timestamp and reply context
            var updatedMessage = parsedMessage
            if let timestamp = currentTimestamp {
                updatedMessage.timestamp = timestamp
            }
            if let context = pendingReplyContext {
                updatedMessage.replyContext = context
                pendingReplyContext = nil
            }

            // Handle messages based on sender
            if updatedMessage.sender == "You" {
                if !pendingSenderMessages.isEmpty {
                    messages.append(contentsOf: pendingSenderMessages)
                    pendingSenderMessages.removeAll()
                }
                messages.append(updatedMessage)
            } else {
                pendingSenderMessages.append(updatedMessage)
            }
        }

        // Handle any remaining pending messages
        if !pendingSenderMessages.isEmpty {
            // Just add the remaining messages as they are
            messages.append(contentsOf: pendingSenderMessages)
        }

        currentData?.messages = messages.filter { $0.value != nil }.map { $0.toVanillaMessage() }
    }

    private func isSenderIdentifierElement(_ element: ElementProtocol) async -> Bool {
        do {
            // Check if element has the characteristics of a sender identifier:
            // - Role is AXUnknown
            // - Has a description
            // - Not a link preview
            if await element.has(role: .unknown),
               try await element.getAttributeValue(.description) is String,
               !(await isLinkPreview(element)) {
                return true
            }
        } catch {
            Log.error("Error checking sender identifier element", error: error)
        }
        return false
    }

    private func groupMessagesByYCoordinate(
        _ messages: [CollectedMessage],
        tolerance: CGFloat = 1.0
    ) async -> [[CollectedMessage]] {
        Log.info("=== Starting groupMessagesByYCoordinate ===", category: .controlFlow)
        Log.info("Input messages count: \(messages.count)", category: .controlFlow)

        var groups: [[CollectedMessage]] = []
        var currentGroup: [CollectedMessage] = []
        var currentY: CGFloat?

        // Preprocess: Gather data required for sorting
        var frames: [(CollectedMessage, CGFloat)] = []

        for message in messages {
            if let frame = message.frame {
                frames.append((message, frame.y))
            } else {
                Log.info("Warning: Missing frame while preprocessing messages", category: .controlFlow)
            }
        }

        // Sort synchronously
        let sortedMessages = frames.sorted { $0.1 < $1.1 }.map { $0.0 }

        Log.debug("Sorted messages count: \(sortedMessages.count)", category: .controlFlow)

        // Debug print frames for sorted messages
        /*
         for (index, message) in sortedMessages.enumerated() {
         if let frame = message.frame {
         debugPrint("Sorted message \(index) frame: x=\(frame.x), y=\(frame.y),
         w=\(frame.width), h=\(frame.height)", .controlFlow)
         } else {
         debugPrint("Sorted message \(index) has no frame", .controlFlow)
         }
         }
         */
        for message in sortedMessages {
            if let frame = message.frame {
                if let currY = currentY {
                    if abs(frame.y - currY) <= tolerance {
                        currentGroup.append(message)
                        // debugPrint("Added message to current group (y=\(frame.y),
                        // current group size: \(currentGroup.count))", .controlFlow)
                    } else {
                        if !currentGroup.isEmpty {
                            groups.append(currentGroup)
                            // debugPrint("Created new group with \(currentGroup.count) messages", .controlFlow)
                        }
                        currentGroup = [message]
                        currentY = frame.y
                    }
                } else {
                    currentGroup = [message]
                    currentY = frame.y
                    Log.info("Started first group with y=\(frame.y)", category: .controlFlow)
                }
            } else {
                Log.info("Skipped message with no frame", category: .controlFlow)
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
            Log.info("Added final group with \(currentGroup.count) messages)", category: .controlFlow)
        }

        Log.info("Created \(groups.count) total groups", category: .controlFlow)
        Log.info("=== Finished groupMessagesByYCoordinate ===", category: .controlFlow)

        return groups
    }

    // MARK: - Message Processing

    private func parseMessageGroup(
        _ messages: [CollectedMessage],
        messagesListFrame: Frame?,
        chatInfo: ChatInfo
    ) async -> ParsedMessage? {
        guard !messages.isEmpty else { return nil }

        // Check for reply context message - return nil if it is one
        for message in messages {
            do {
                if let identifier = try await message.element.getAttributeValue(.identifier) as? String,
                   identifier == "reply_context_message" {
                    return nil
                }
            } catch {
                continue
            }
        }

        // Collect frames and message elements
        var frames: [Frame] = []
        var messageElements: [MessageElement] = []
        var allImages = true
        var imageCount = 0

        for message in messages {
            if let frame = message.frame {
                frames.append(frame)
            }

            let elements = await parseMessageElement(
                message.element,
                messagesListFrame: messagesListFrame,
                otherPerson: chatInfo.otherPerson
            )
            messageElements.append(contentsOf: elements)

            if await isImageMessage(message.element) {
                imageCount += 1
            } else {
                allImages = false
            }
        }

        guard let mergedFrame = Frame.merge(frames) else { return nil }

        let sender: String?
        if let mlFrame = messagesListFrame {
            sender = determineSender(
                messageFrame: mergedFrame,
                messagesListFrame: mlFrame,
                otherPerson: chatInfo.otherPerson ?? "Unknown"
            )
        } else {
            sender = nil
        }

        // Handle image group
        if allImages, imageCount > 1 {
            return ParsedMessage(
                sender: sender,
                messageType: "Images (\(imageCount))",
                frame: mergedFrame,
                count: imageCount
            )
        }

        // Process as single message
        let (messageType, value, timestamp) = await getMessageTypeAndValue(messages[0].element)

        if messageType == "Skip" { return nil }

        return ParsedMessage(
            sender: sender,
            messageType: messageType,
            frame: mergedFrame,
            value: value,
            timestamp: timestamp,
            rawElements: messageType == "Unknown" ? messageElements : nil
        )
    }

    private func parseMessageElement(
        _ element: ElementProtocol,
        depth: Int = 0,
        messagesListFrame: Frame?,
        otherPerson: String?
    ) async -> [MessageElement] {
        var results: [MessageElement] = []

        do {
            let frame = await Frame.from(element: element)

            var sender: String?
            if let frame,
               let mlFrame = messagesListFrame,
               let other = otherPerson,
               depth == 0 {
                sender = determineSender(
                    messageFrame: frame,
                    messagesListFrame: mlFrame,
                    otherPerson: other
                )
            }

            // Get attributes, checking for nil
            let role = try await element.getAttributeValue(.role) as? Role
            let identifier = try await element.getAttributeValue(.identifier) as? String
            let description = try await element.getAttributeValue(.description) as? String
            let value = try await element.getValue()

            // If any attribute exists, create the MessageElement
            if role != nil || identifier != nil || description != nil || value != nil {
                results.append(MessageElement(
                    role: role?.rawValue ?? "",
                    identifier: identifier ?? "",
                    description: description ?? "",
                    value: value ?? "",
                    depth: depth,
                    sender: sender,
                    frame: frame
                ))
            }

            // Process children
            if let children = try await element.getChildren() {
                for child in children {
                    let childElements = await parseMessageElement(
                        child,
                        depth: depth + 1,
                        messagesListFrame: messagesListFrame,
                        otherPerson: otherPerson
                    )
                    results.append(contentsOf: childElements)
                }
            }
        } catch {
            Log.error("Error parsing message element", error: error)
        }

        return results
    }

    // MARK: - Message Type Detection

    private func isAdminMessage(_ element: ElementProtocol) async -> Bool {
        do {
            if let identifier = try await element.getAttributeValue(.identifier) as? String,
               identifier == "admin-message" {
                return true
            }

            if let children = try await element.getChildren() {
                for child in children {
                    if let childId = try await child.getAttributeValue(.identifier) as? String,
                       childId == "admin-message" {
                        return true
                    }
                }
            }
        } catch {
            Log.error("Error checking admin message", error: error)
            return false
        }

        return false
    }

    private func isImageMessage(_ element: ElementProtocol) async -> Bool {
        do {
            if let description = try await element.getAttributeValue(.description) as? String,
               description == "Image" {
                return true
            }

            if let children = try await element.getChildren() {
                for child in children {
                    if let childId = try await child.getAttributeValue(.identifier) as? String,
                       childId == "image-message-view" {
                        return true
                    }
                }
            }
        } catch {
            Log.error("Error checking image message", error: error)
        }

        return false
    }

    private func isLinkPreview(_ element: ElementProtocol) async -> Bool {
        do {
            guard await element.has(role: .unknown) else {
                return false
            }

            if let children = try await element.getChildren() {
                for child in children {
                    if await child.has(role: .image) {
                        return true
                    }
                }
            }
            return false

        } catch {
            return false
        }
    }

    private func getMessageTypeAndValue(_ element: ElementProtocol) async -> (
        type: String,
        value: String?,
        timestamp: Date?
    ) {
        do {
            // Check for admin message
            if await isAdminMessage(element) {
                var adminValue: String?

                if let children = try await element.getChildren() {
                    for child in children {
                        if let childId = try await child.getAttributeValue(.identifier) as? String,
                           childId == "admin-message",
                           let value = try await child.getValue() {
                            adminValue = value
                            break
                        }
                    }
                }
                if adminValue == nil {
                    adminValue = try await element.getAttributeValue(.description) as? String
                }

                if let value = adminValue,
                   await isDateTimeMessage(value) {
                    return ("Admin", value, DateReformatter.parseMessengerDateTime(value))
                }

                return ("Skip", nil, nil)
            }

            // Check for hotlike message
            if let identifier = try await element.getAttributeValue(.identifier) as? String,
               identifier == "hotlike_message" {
                return ("Like", nil, nil)
            }

            // Check for image
            if await isImageMessage(element) {
                return ("Image", nil, nil)
            }

            // Check children for text or emoji messages
            if let children = try await element.getChildren() {
                for child in children {
                    if let childId = try await child.getAttributeValue(.identifier) as? String {
                        if childId == "text-message" || childId == "emoji-message",
                           let value = try await child.getValue() {
                            return ("Text", value, nil)
                        }
                    }
                }
            }
        } catch {
            Log.error("Error getting message type", error: error)
        }

        return ("Unknown", nil, nil)
    }

    private func isDateTimeMessage(_ value: String) async -> Bool {
        let patterns = [
            #"^\d{1,2}:\d{2} [AP]M$"#, // 3:02 PM
            #"^(MON|TUE|WED|THU|FRI|SAT|SUN) \d{1,2}:\d{2} [AP]M$"#, // THU 2:27 PM
            #"^\d{2}/\d{2}/\d{4}, \d{1,2}:\d{2} [AP]M$"#, // 08/24/2016, 8:36 PM
            #"^(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC) \d{2}, \d{1,2}:\d{2} [AP]M$"#, // NOV 07, 4:27 AM
        ]

        let upperValue = value.uppercased()
        return patterns.contains { pattern in
            upperValue.range(of: pattern, options: .regularExpression) != nil
        }
    }

    // MARK: - Helper Functions

    private func shouldIgnoreElement(_ element: ElementProtocol) async -> Bool {
        do {
            if let role = try await element.getAttributeValue(.role) as? Role,
               [.button, .scrollBar, .staticText].contains(role) {
                return true
            }

            if let identifier = try await element.getAttributeValue(.identifier) as? String,
               ["message_reaction", "message_delivery_status_delivered", "message-seen-heads"].contains(identifier) {
                return true
            }
        } catch {
            Log.error("Error checking element", error: error)
        }
        return false
    }

    private func determineSender(messageFrame: Frame, messagesListFrame: Frame, otherPerson: String) -> String {
        let distToLeft = abs(messageFrame.leftSide - messagesListFrame.leftSide)
        let distToRight = abs(messageFrame.rightSide - messagesListFrame.rightSide)
        return distToLeft < distToRight ? otherPerson : "You"
    }

    private func extractChatInfo(from windowElement: ElementProtocol) async -> ChatInfo {
        let threadNameCollector = Collectors.makeTextCollector()
        let threadNameRule = Rule(
            matcher: Matchers.hasAttribute(.identifier, equalTo: "chat_header_thread_name"),
            collector: threadNameCollector
        )

        let groupCollector = Collectors.makeBooleanFlagCollector(
            condition: Matchers.hasAttribute(.description, substring: "Group audio call")
        )
        let groupCheckRule = Rule(
            matcher: Matchers.hasAttribute(.identifier, equalTo: "audio_call_button"),
            collector: groupCollector
        )

        // Exclude the Threads List from the search
        let excludeThreadsList = Matchers.hasAttribute(.description, equalTo: "Threads List")

        do {
            try await windowElement.traverse(
                rules: [threadNameRule, groupCheckRule],
                excludeMatchers: [excludeThreadsList],
                terminateAfterAllRules: true
            )

            // Get the collected values
            let name = await threadNameCollector.getFirst() ?? "Unknown"
            let isGroup = await groupCollector.getFirst() ?? false

            return ChatInfo(
                name: name,
                isGroup: isGroup,
                otherPerson: isGroup ? nil : name
            )
        } catch {
            Log.error("Error traversing window", error: error)
            return ChatInfo(name: "Unknown", isGroup: false, otherPerson: "Unknown")
        }
    }

    private func findMessagesList(in elements: [(StackItem, ElementProtocol)]) async -> (StackItem, ElementProtocol)? {
        for (stackItem, element) in elements {
            do {
                if let description = try await element.getAttributeValue(.description) as? String,
                   description == "Messages List" {
                    return (stackItem, element)
                }
            } catch {
                continue
            }
        }
        return nil
    }
}
