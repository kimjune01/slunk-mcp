import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

public actor SignalParser: CustomParser {
    public let parsedApp: ParseableApp = .signal

    // Cached date formatters for better performance
    private let longDateParseStrategy = Date.FormatStyle()
        .month(.wide)
        .day()
        .year()
        .parseStrategy

    private let shortDateParseStrategy = Date.FormatStyle()
        .weekday(.abbreviated)
        .month(.abbreviated)
        .day()
        .parseStrategy

    private let timeParseStrategy = Date.FormatStyle()
        .hour(.defaultDigits(amPM: .abbreviated))
        .minute(.twoDigits)
        .parseStrategy

    private var currentConversation: Conversation
    private var currentDateInfo: String?
    private var floatingHeaderDateInfo: String? // Store floating header date separately
    private var pendingTimeString: Int = 0
    private var pendingSender: Int = 0
    private var pendingDateInfo: Int = 0 // Track messages pending date info
    private var lastKnownSender: String?

    public init() {
        self.currentConversation = Conversation(app: parsedApp.title)
    }

    public func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        do {
            currentConversation = Conversation(app: parsedApp.title)
            try await processSignalWindow(params.accessWindow, deadline: deadline)
            return ParseResult(activeConversation: currentConversation)
        } catch {
            Log.error("Error parsing Signal window", error: error)
            return .empty
        }
    }

    private func processSignalWindow(_ element: ElementProtocol, deadline: Deadline) async throws {
        // Get channel name
        if let panel = try await element.findElementWithClass("ConversationView") {
            if let header = try await panel.findElementWithClass("module-ConversationHeader__header--clickable") {
                if let channel = try await header.getFirstChildValue() {
                    currentConversation.channel = channel
                } else if let channel = try await header.getAttributeValue(.title) as? String {
                    currentConversation.channel = channel
                }
            }
            // look for a floating date header but don't set currentDateInfo yet
            if let dateFloatingHeader = try await panel.findElementWithClass("TimelineFloatingHeader") {
                if let dateHeader = try await dateFloatingHeader.collectTreeValues() {
                    floatingHeaderDateInfo = dateHeader
                }
            }
            // Process message list
            if let messageList = try await panel.findElement(
                matching: Matchers.hasAttribute(.subrole, equalTo: Subrole.contentList)
            ) {
                try await processMessageList(messageList, deadline: deadline)

                // If we reach the end and still have pending date info, apply the floating header date
                if pendingDateInfo > 0, floatingHeaderDateInfo != nil {
                    applyToPreviousMessagesWithDateInfo(floatingHeaderDateInfo!)
                }
            }
        }
    }

    private func processMessageList(_ messageList: ElementProtocol, deadline: Deadline) async throws {
        guard let children = try await messageList.getChildren() else { return }

        // Determine if group chat by looking for author class in first message
        let isGroup = try await children.first?.findElementWithClass("module-message__author") != nil
        currentConversation.isGroup = isGroup

        for messageElement in children {
            if deadline.hasPassed { break }
            if let dateInlineHeader = try await messageElement.findElementWithClass("TimelineDateHeader") {
                if let dateHeader: String = try await dateInlineHeader.collectTreeValues() {
                    // Apply date to previous messages with pending date info
                    if pendingDateInfo > 0 {
                        applyToPreviousMessagesWithDateInfo("Before \(dateHeader)")
                    }

                    // Set current date info for upcoming messages
                    currentDateInfo = dateHeader
                    pendingDateInfo = 0
                }
            }
            if let messageWrapper = try await messageElement.findElementWithClass("module-message__wrapper"),
               // if not inline date information process as message
               let messageContainer = try await messageWrapper.findElementWithClass("module-message") {
                if let message = try await processMessage(messageContainer, isGroup: isGroup) {
                    currentConversation.messages.append(message)

                    // If we don't have date info for this message, increment pending counter
                    if currentDateInfo == nil {
                        pendingDateInfo += 1
                    }
                }
            }
        }
    }

    private func processMessage(_ element: ElementProtocol, isGroup: Bool) async throws -> Message? {
        var message = Message()

        // Set sender
        if isGroup {
            if try await element.hasClass("module-message--outgoing") {
                message.sender = "You"
            } else if let newSender = try await processGroupMessageSender(element) {
                // We found a new sender
                message.sender = newSender
                lastKnownSender = newSender

                // If we had pending messages without senders, update them
                if pendingSender > 0 {
                    applyToPreviousMessages(sender: newSender)
                    pendingSender = 0
                }
            } else {
                // No explicit sender found, use last known sender or mark as pending
                if let lastSender = lastKnownSender {
                    message.sender = lastSender
                } else {
                    pendingSender += 1
                }
            }
        } else {
            message.sender = try await processOneOnOneMessageSender(element)
        }

        // Process content
        if let container = try await element.findElementWithClass("module-message__container") {
            let (content, type) = try await processMessageContent(container)
            if let content = content {
                message.content = filterOutBadWhitespaces(in:content)
            }
            message.messageType = type

            // Handle photos
            if try await container.findElementWithClass("module-image") != nil {
                message.messageType = (message.messageType ?? "") + (message.messageType == nil ? "" : ", ") + "photo"
                if message.content == nil {
                    message.content = "[Photo]"
                }
            }
        }

        if let dateMetadata = try await element
            .findElementWithClass("module-message__metadata__date")?.collectTreeValues() {
            message.timestring = dateMetadata
            if let timestamp = produceTimestamp(dateMetadata) {
                message.timeSent = timestamp
                if pendingTimeString > 0 {
                    applyToPreviousMessage(timestamp)
                    pendingTimeString = 0
                }
            }
        } else {
            pendingTimeString += 1
        }

        // Validate message
        if let sender = message.sender,
           let content = message.content,
           let messageType = message.messageType,
           !sender.isEmpty,
           !content.isEmpty,
           !messageType.isEmpty {
            return message
        }

        return nil
    }

    private func applyToPreviousMessages(sender: String) {
        // Get the number of messages to update based on pendingSender
        let messagesToUpdate = min(pendingSender, currentConversation.messages.count)

        // Only proceed if we have messages to update
        guard messagesToUpdate > 0 else { return }

        // Get the starting index for updates
        let startIndex = currentConversation.messages.count - messagesToUpdate

        // Update senders for the last N messages
        for index in startIndex..<currentConversation.messages.count {
            currentConversation.messages[index].sender = sender
        }
    }

    private func applyToPreviousMessage(_ timestamp: Date) {
        // Get the number of messages to update based on pendingTimeString
        let messagesToUpdate = min(pendingTimeString, currentConversation.messages.count)

        // Only proceed if we have messages to update
        guard messagesToUpdate > 0 else { return }

        // Get the starting index for updates
        let startIndex = currentConversation.messages.count - messagesToUpdate

        // Update timestamps for the last N messages
        for index in startIndex..<currentConversation.messages.count {
            currentConversation.messages[index].timeSent = timestamp
        }
    }

    private func applyToPreviousMessagesWithDateInfo(_ dateInfo: String) {
        // Get the number of messages to update based on pendingDateInfo
        let messagesToUpdate = min(pendingDateInfo, currentConversation.messages.count)

        // Only proceed if we have messages to update
        guard messagesToUpdate > 0 else { return }

        // Get the starting index for updates
        let startIndex = currentConversation.messages.count - messagesToUpdate

        // Create a temporary date info string for these messages
        let tempDateInfo = dateInfo

        // Apply the date info to relevant timestamps
        for index in startIndex..<currentConversation.messages.count {
            if let timestring = currentConversation.messages[index].timestring {
                currentConversation.messages[index].timeSent = produceTimestamp(timestring, withDateInfo: tempDateInfo)
            }
        }

        // Reset pending counter
        pendingDateInfo = 0
    }

    private func processOneOnOneMessageSender(_ element: ElementProtocol) async throws -> String? {
        // Check for outgoing/incoming class on the message element itself
        if try await element.hasClass("module-message--outgoing") {
            return "You"
        } else if try await element.hasClass("module-message--incoming") {
            return currentConversation.channel
        }
        return nil
    }

    private func processGroupMessageSender(_ element: ElementProtocol) async throws -> String? {
        // First try to get sender from author element
        if let authorElement = try await element.findElementWithClass("module-message__author"),
           let sender = try await authorElement.getFirstChildValue() {
            return sender
        }

        // Fallback to avatar if no author element found
        if let avatarElement = try await element.findElementWithClass("module-Avatar"),
           let description = try await avatarElement.getAttributeValue(.description) as? String,
           description.hasPrefix("Avatar for contact") {
            // remove Avatar for contact a space and hidden chars
            return String(description.dropFirst(20).dropLast(1))
        }

        return nil
    }

    private func processMessageContent(_ container: ElementProtocol) async throws -> (content: String?, type: String?) {
        var messageContent: String?
        var messageType: String?

        // Process quote/reply first
        if let quote = try await container.findElementWithClass("module-quote") {
            let (quoteContent, quoteType) = try await processQuoteContent(quote)
            if let quoteContent {
                messageContent = quoteContent
                messageType = quoteType
            }
        }

        if let linkPreview = try await container.findElementWithClass("module-message__link-preview") {
            let linkPreviewText = try await linkPreview.collectTreeValues() ?? ""
            messageContent = (messageContent ?? "") + (messageContent == nil ? "" : " ") + linkPreviewText
            messageType = (messageType ?? "") + (messageType == nil ? "" : ", ") + "link"
        }

        // Process main message text
        if let textElement = try await container.findElementWithClass("module-message__text") {
            if try await textElement.hasClassContaining("delete") {
                messageContent = "[This message was deleted]"
                messageType = "deleted"
            } else {
                let excludeLinkPredicate = Matchers.not(Matchers.hasRole(.link))
                if let textContent = try await textElement
                    .collectTreeValuesOrDescriptions(matching: excludeLinkPredicate) {
                    messageContent = (messageContent ?? "") + (messageContent == nil ? "" : " ") + textContent
                    messageType = (messageType ?? "") + (messageType == nil ? "" : ", ") + "text"
                }
            }
        }

        return (messageContent, messageType)
    }

    private func processQuoteContent(_ quote: ElementProtocol) async throws -> (content: String?, type: String?) {
        // Get author of quoted message
        let authorName = if let authorElement = try await quote.findElementWithClass("module-quote__primary__author") {
            try await authorElement.collectTreeValuesOrDescriptions() ?? "Unknown"
        } else {
            currentConversation.isGroup ? currentConversation.channel : "You"
        }
        // Get quoted text content
        if let textElement = try await quote.findElementWithClass("module-quote__primary__text") {
            let quotedText = try await textElement.collectTreeValuesOrDescriptions() ?? ""
            let prefix = "(Replying to \(authorName): \(quotedText)) "
            return (prefix, "reply-to")
        }

        return (nil, nil)
    }

    // Update to add year correction in "Before X" block for shortDateParseStrategy

    private func produceTimestamp(_ timestring: String, withDateInfo: String? = nil) -> Date? {
        // Use provided date info or current date info
        guard let dateInfo = withDateInfo ?? currentDateInfo else { return nil }

        let calendar = Calendar.current
        let now = Date()

        // First parse the date portion
        let baseDate: Date = {
            // Handle "Before X" format specially
            if let range = dateInfo.range(of: "Before ") {
                let actualDate = String(dateInfo[range.upperBound...])
                // Try processing the actual date part
                if actualDate == "Today" {
                    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
                        return now
                    }
                    return yesterday
                } else if actualDate == "Yesterday" {
                    guard let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now) else {
                        return now
                    }
                    return twoDaysAgo
                } else if let date = try? longDateParseStrategy.parse(actualDate) {
                    // Make it one day earlier since it's "Before X"
                    return calendar.date(byAdding: .day, value: -1, to: date) ?? date
                } else if let date = try? shortDateParseStrategy.parse(actualDate) {
                    // Add year correction logic for short dates (same as in default block)
                    var components = calendar.dateComponents([.month, .day], from: date)
                    components.year = calendar.component(.year, from: now)

                    if let dateWithYear = calendar.date(from: components) {
                        // If the resulting date is in the future, subtract a year
                        if dateWithYear > now {
                            components.year = components.year! - 1
                        }

                        // Get the corrected date with year and make it one day earlier
                        if let correctedDate = calendar.date(from: components) {
                            return calendar.date(byAdding: .day, value: -1, to: correctedDate) ?? correctedDate
                        }
                    }

                    // Fallback to original behavior if year correction fails
                    return calendar.date(byAdding: .day, value: -1, to: date) ?? date
                }
            }

            // Normal date processing for non "Before X" formats
            switch dateInfo {
            case "Today":
                return now

            case "Yesterday":
                guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
                    return now
                }
                return yesterday

            default:
                // Try parsing with modern FormatStyle approaches
                if let date = try? longDateParseStrategy.parse(dateInfo) {
                    return date
                }

                if let date = try? shortDateParseStrategy.parse(dateInfo) {
                    // For short dates, we need to handle the year
                    var components = calendar.dateComponents([.month, .day], from: date)
                    components.year = calendar.component(.year, from: now)

                    if let dateWithYear = calendar.date(from: components) {
                        // If the resulting date is in the future, subtract a year
                        if dateWithYear > now {
                            components.year = components.year! - 1
                        }
                        return calendar.date(from: components) ?? now
                    }
                }

                return now
            }
        }()

        // Then parse the time portion
        let finalDate: Date? = {
            // Handle "Xm" format (where X is minutes)
            if timestring.hasSuffix("m") {
                let minutesString = timestring.dropLast()
                if let minutes = Int(minutesString) {
                    return calendar.date(byAdding: .minute, value: -minutes, to: now)
                }
            }

            // Handle "H:MM AM/PM" format using FormatStyle
            if let time = try? timeParseStrategy.parse(timestring) {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

                var finalComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
                finalComponents.hour = timeComponents.hour
                finalComponents.minute = timeComponents.minute

                return calendar.date(from: finalComponents)
            }

            return nil
        }()

        return finalDate
    }
    private func filterOutBadWhitespaces(in input:String) -> String {
        // Filter out invisible characters except spaces and newlines
        return input.filter { char in
            char == " " || char == "\n" || !char.isWhitespace
        }
    }

}
