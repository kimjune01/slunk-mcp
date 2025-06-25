import ApplicationServices
import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

private struct WhatsAppMessageContent {
    let content: String
    let dateString: String
    let timeString: String
    let recipientInfo: String
    let metadata: [String]

    var fullDateTimeString: String {
        "\(dateString) \(timeString)"
    }

    var timestamp: Date {
        return DateReformatter.formatWhatsAppTime(fullDateTimeString) ?? Date()
    }
}

actor WhatsAppParser: CustomParser {
    public let parsedApp: ParseableApp = .whatsapp

    private var currentData: Conversation?
    private var conversationName: String = ""
    static let messageTypes: [(prefix: String, metadata: String)] = [
        ("message,", "message"),
        ("Message from", "message"),
        ("Replying to", "Reply"),
        ("Forwarded.", "Forwarded"),
        ("Video,", "Video attachment"),
        ("Video from", "Video attachment"),
        ("Photo,", "Photo attachment"),
        ("Photo from", "Photo attachment"),
        ("Your message,", "message"),
        ("Your video,", "Video attachment"),
        ("Your photo,", "Photo attachment"),
    ]

    public init() {}

    func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        Log.info("WhatsAppParser.parse() called", category: .controlFlow)
        Log.info("==========================++===========================", category: .controlFlow)
        try await processWhatsAppWindow(params.accessWindow, deadline: deadline)

        if let data = currentData {
            return ParseResult(activeConversations: [data])
        } else {
            Log.error("WhatsAppParser failed to parse")
            return .empty
        }
    }

    private func processWhatsAppWindow(_ element: ElementProtocol, deadline: Deadline) async throws {
        let stack = [StackItem(element: element, path: [])]
        var processedStack = [(StackItem, ElementProtocol)]()
        var tableCount = 0

        // First pass: collect all relevant elements
        await collectRelevantElements(from: stack, into: &processedStack, deadline: deadline)

        // Second pass: process collected elements
        for (stackItem, element) in processedStack {
            if deadline.hasPassed { break }

            if let roleDescription = try await element.getAttributeValue(.roleDescription) as? String,
               roleDescription == "table" {
                tableCount += 1
                // Skip the first table of conversations, (tableCount == 1)
                if tableCount == 2 {
                    try await processMessagesList(element, stackItem: stackItem, deadline: deadline)
                    break // We found what we needed
                }
            }
        }
    }
    
    private func collectRelevantElements(from initialStack: [StackItem],
                                         into processed: inout [(StackItem, ElementProtocol)],
                                         deadline: Deadline) async {
        
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

    private func parseMessage(_ description: String) -> Message? {
        let cleanDescription = description.replacingOccurrences(of: "\u{200e}", with: "")

        guard let (matchedPrefix, metadata) = WhatsAppParser.messageTypes.first(where: {
            cleanDescription.starts(with: $0.prefix)
        }) else {
            return nil
        }

        var sender: String?
        var content = ""
        var timestamp: Date?
        var timestring: String?
//        var metadata = [initialMetadata]

        // Extract sender
        if matchedPrefix == "Message from" || cleanDescription.contains("Message from") ||
            matchedPrefix == "Video from" || matchedPrefix == "Photo from" {
            let fromIndex = cleanDescription.range(of: "from")!.upperBound
            if let firstComma = cleanDescription[fromIndex...].firstIndex(of: ",") {
                sender = String(cleanDescription[fromIndex..<firstComma]).trimmingCharacters(in: .whitespaces)
            }
        } else if matchedPrefix.starts(with: "Your") {
            sender = "You"
        }

        let messageStart: String.Index
        if let fromComma = cleanDescription.firstIndex(of: ",") {
            messageStart = cleanDescription.index(after: fromComma)
        } else {
            messageStart = cleanDescription.startIndex
        }

        if let whatsAppMessageContent = parseMessageContent(
            String(cleanDescription[messageStart...])
        ) {
            content = whatsAppMessageContent.content
            timestamp = whatsAppMessageContent.timestamp
            timestring = whatsAppMessageContent.fullDateTimeString

            // Ignore any additional metadata for now
//            metadata.append(contentsOf: additionalMetadata)
            // Always parse recipient info for conversation name
            if let (type, name) = parseRecipientInfo(whatsAppMessageContent.recipientInfo) {
                // Update sender only if not set
                if sender == nil {
                    switch type {
                    case .sender:
                        sender = name
                    case .recipient:
                        sender = "You"
                    case .group:
                        if let existingSender = sender {
                            sender = existingSender
                        }
                    }
                }
            }
        }

        return Message(
            sender: sender,
            content: content.isEmpty ? metadata : content,
            // For media files the content will be empty, adding description metadata
            timestamp: timestamp ?? Date(),
            messageType: nil,
            timestring: timestring ?? Date().ISO8601Format()
        )
    }

    private enum RecipientType {
        case sender // "Received from"
        case recipient // "Sent to"
        case group // "Received in"
    }

    private func parseRecipientInfo(_ info: String) -> (RecipientType, String)? {
        let info = info.trimmingCharacters(in: .whitespaces)
        if info.contains("Received from") {
            let name = info.replacingOccurrences(of: "Received from ", with: "")
            if conversationName.isEmpty {
                conversationName = name
            }
            return (.sender, name)
        } else if info.contains("Sent to") {
            let name = info.replacingOccurrences(of: "Sent to ", with: "")
            if conversationName.isEmpty {
                conversationName = name
            }
            return (.recipient, name)
        } else if info.contains("Received in") {
            let name = info.replacingOccurrences(of: "Received in ", with: "")
            if conversationName.isEmpty {
                conversationName = name
            }
            return (.group, name)
        }
        return nil
    }

    private func parseMessageContent(_ content: String) -> WhatsAppMessageContent? {
        var parts = content.split(separator: ",", omittingEmptySubsequences: false)
        // Need at least 3 parts: content, timestamp info, recipient info
        guard parts.count >= 3 else { return nil }
        var additionalMetadata: [String] = []

        // Process all status indicators at the end
        var foundStatus = true
        while foundStatus, let lastPart = parts.last {
            let trimmedPart = lastPart.trimmingCharacters(in: .whitespaces)
            foundStatus = false // Reset flag - will be set to true if we find a status
            switch trimmedPart {
            case "Red":
                additionalMetadata.append("Read")
                parts.removeLast()
                foundStatus = true
            case "Delivered":
                additionalMetadata.append("Delivered")
                parts.removeLast()
                foundStatus = true
            case "Starred":
                additionalMetadata.append("Starred")
                parts.removeLast()
                foundStatus = true
            case "Edited":
                additionalMetadata.append("Edited")
                parts.removeLast()
                foundStatus = true
            case "Pinned":
                additionalMetadata.append("Pinned")
                parts.removeLast()
                foundStatus = true
            default:
                break
            }
        }

        // Last part should now be recipient info - preserve it with its leading space
        guard let recipientInfo = parts.last else { return nil }
        parts.removeLast()

        // Always get the time part first
        guard let timePart = parts.last?.trimmingCharacters(in: .whitespaces) else { return nil }
        parts.removeLast()

        // Check for date part
        var dateStr = ""
        if timePart.hasPrefix("at") {
            // If time starts with "at", the previous part must be the date
            guard let datePart = parts.last else { return nil }
            dateStr = datePart.trimmingCharacters(in: .whitespaces)
            parts.removeLast()
        }

        // Clean up time string
        let timeStr = timePart.replacingOccurrences(of: "at", with: "").trimmingCharacters(in: .whitespaces)

        // All remaining parts form the message content
        let messageContent = parts.joined(separator: ",").trimmingCharacters(in: .whitespaces)

        return WhatsAppMessageContent(
            content: messageContent,
            dateString: dateStr,
            timeString: timeStr,
            recipientInfo: String(recipientInfo),
            metadata: additionalMetadata
        )
    }

    // "November26 8:54 PM"
    private func extractDateTime(from parts: [String]) -> (date: String, time: String) {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd"
        let todayStr = formatter.string(from: today)

        // Check if we have two parts
        if parts.count == 2 {
            let first = parts[0]
            let second = parts[1]

            // If second part starts with "at", first part should be the date
            if second.hasPrefix("at") {
                return (first, second.replacingOccurrences(of: "at", with: "").trimmingCharacters(in: .whitespaces))
            }

            // If first part has a month name, it's the date
            let monthNames = [
                "January",
                "February",
                "March",
                "April",
                "May",
                "June",
                "July",

                "August",
                "September",
                "October",
                "November",
                "December",
            ]
            if monthNames.contains(where: { first.contains($0) }) {
                return (first, second)
            }
        }

        // If we just have one part and it contains AM/PM, it's today's time
        if let lastPart = parts.last, lastPart.contains("AM") || lastPart.contains("PM") {
            return (todayStr, lastPart)
        }

        // Default to today and last part as time
        return (todayStr, parts.last ?? "")
    }

    private func formatTimestamp(_ timestamp: String) -> Date {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)

        var cleanTimestamp = timestamp.trimmingCharacters(in: .whitespaces)

        // Add space between month and day number if missing
        let monthNames = [
            "January",
            "February",
            "March",
            "April",
            "May",
            "June",
            "July",

            "August",
            "September",
            "October",
            "November",
            "December",
        ]

        for month in monthNames where cleanTimestamp.contains(month) {
            let pattern = "\(month)\\d+"
            if cleanTimestamp.range(of: pattern, options: .regularExpression) != nil {
                let monthEnd = cleanTimestamp.index(cleanTimestamp.startIndex, offsetBy: month.count)
                cleanTimestamp.insert(" ", at: monthEnd)
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM dd h:mm a"

        if var date = dateFormatter.date(from: cleanTimestamp) {
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            components.year = year
            if let dateWithYear = calendar.date(from: components) {
                date = dateWithYear
                return date
            }
        }

        return Date()
    }

    private func processMessagesList(
        _ element: ElementProtocol,
        stackItem: StackItem,
        deadline: Deadline
    ) async throws {
        var messages: [Message] = []
        // Reset both currentData and conversationName for new message list processing
        currentData = nil
        conversationName = ""
        try await processGroup(stackItem, deadline: deadline, messages: &messages)

        // Create or update conversation with parsed messages
        if !messages.isEmpty {
            currentData = Conversation(app: parsedApp.title, channel: conversationName, messages: messages)
        }
    }

    private func processGroup(_ stackItem: StackItem, deadline: Deadline, messages: inout [Message]) async throws {
        let skipElements: ElementMatcher = { element in
            if let role = try? await element.getAttributeValue(.role) as? Role,
               [.heading, .staticText, .link, .button].contains(role) {
                return true
            }
            return false
        }
        
        let sequence = ElementDepthFirstSequence(
            element: stackItem.element,
            excludeElement: skipElements,
            deadline: deadline
        )
        
        for try await item in sequence {
            if deadline.hasPassed { break }
            
            let element = item.element
            
            if let role = try await element.getAttributeValue(.role) as? Role, 
               role == .genericElement,
               let description = try await element.getAttributeValue(.description) as? String {
                
                if let message = parseMessage(description) {
                    messages.append(message)
                }
            }
        }
    }
}
