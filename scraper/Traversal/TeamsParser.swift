import ApplicationServices
import AsyncAlgorithms
import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics
import OSLog

actor TeamsStateManager {
    // Singleton used to store initialization status for Microsoft Teams a11y
    // Teams does not expose its a11y tree until an element is accessed via the system wide element

    public static let shared = TeamsStateManager()

    private var initializedPid: pid_t?
    private var isInitialized = false

    private init() {}

    // Check if Teams is already initialized for a specific PID
    func isInitializedForPid(_ pid: pid_t) -> Bool {
        return initializedPid == pid && isInitialized
    }

    // Store initialization success
    func setInitialized(forPid pid: pid_t) {
        Log.info("Teams initialization state saved", category: .controlFlow)
        initializedPid = pid
        isInitialized = true
    }

    // Reset initialization state (can be called when initialization fails)
    func resetInitialization() {
        Log.info("Teams initialization state reset", category: .controlFlow)
        initializedPid = nil
        isInitialized = false
    }
}

actor TeamsParser: CustomParser {
    public let parsedApp: ParseableApp = .microsoftteams

    private lazy var monitoringService = MonitoringService()

    public init() {}

    private func initializeAccessibility(params: WindowParams) async -> Bool {
        // Check if we've already initialized for this PID using the shared state manager
        if await TeamsStateManager.shared.isInitializedForPid(params.appPid) {
            Log.info("Teams already initialized (from shared state)", category: .controlFlow)
            return true
        }

        Log.info("Initializing Teams accessibility", category: .controlFlow)

        // We need to access the Teams a11y element from the system wide element to "unlock" the a11y tree.
        // Use the window that was passed to us - we're already working with a window
        let window = params.accessWindow

        // Perform the "unlock" hit test using the provided window
        var frame: CGRect?
        if let position: Point = try? await window.getAttributeValue(.position) as? Point,
           let size: Size = try? await window.getAttributeValue(.size) as? Size {
            frame = CGRect(x: position.x, y: position.y, width: size.width, height: size.height)
        }

        guard let teamsFrame = frame else {
            Log.info("Could not determine Teams window frame", category: .controlFlow)
            return false
        }

        let midPointX = teamsFrame.minX + (teamsFrame.width / 2)
        let midPointY = teamsFrame.minY + (teamsFrame.height / 2)
        Log.info("midPointX \(midPointX) midPointY \(midPointY)", category: .controlFlow)

        let systemWideElement = await Element()

        guard let teamsElementFromSystemWide = try? await systemWideElement.elementAtPosition(
            x: Float(midPointX),
            y: Float(midPointY)
        ) else {
            Log.info("teamsElementFromSystemWide ERROR", category: .controlFlow)
            return false
        }

        guard let pid = try? await teamsElementFromSystemWide.getProcessIdentifier() else {
            Log.info("Could not get process identifier from Teams element", category: .controlFlow)
            return false
        }

        guard pid == params.appPid else {
            Log.info("teamsElementFromSystemWide PID does not match Teams PID", category: .controlFlow)
            return false
        }

        // We'll only mark it as initialized if we successfully parse meaningful data
        Log.info("Teams PID matches hit-test", category: .controlFlow)
        return true
    }

    func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        Log.info("""
        TeamsParser.parse() called
        =======================================================
        """, category: .controlFlow)

        // First make sure Teams is unlocked
        let unlocked = await initializeAccessibility(params: params)
        if !unlocked {
            Log.info("Teams accessibility initialization failed, returning empty result", category: .controlFlow)
            return ParseResult.empty
        }

        let elementSequence = ElementDepthFirstSequence(element: params.accessWindow, childType: .children)
        var conversationSummaries: [ConversationSummary] = []
        var activeConversation = Conversation(app: parsedApp.title, messages: [])
        var events = CalendarEvents(events: [])
        var foundMeaningfulData = false

        for try await item in elementSequence {
            if deadline.hasPassed { break }

            if let role = try? await item.element.getAttributeValue(.role) as? Role {
                switch role {
                case .list:
                    if let description = try? await item.element.getAttributeValue(.description) as? String {
                        if description.contains("calendar") || description.contains("meeting") {
                            let results = await processCalendarEvents(item.element, deadline: deadline)
                            if !results.isEmpty {
                                foundMeaningfulData = true
                                events.events.append(contentsOf: results)
                            }
                        }
                    }

                case .group:
                    let description = try? await item.element.getAttributeValue(.description) as? String

                    if let description, description.contains("Chat") {
                        let chats = try await processTeamsList(item.element, deadline: deadline)
                        if !chats.isEmpty {
                            foundMeaningfulData = true
                            conversationSummaries = chats
                        }
                    } else {
                        let messages = try await processMessagesList(item.element, deadline: deadline)
                        if !messages.isEmpty {
                            foundMeaningfulData = true
                            activeConversation.messages.append(contentsOf: messages)
                        }

                        let results = await processCalendarEvents(item.element, deadline: deadline)
                        if !results.isEmpty {
                            foundMeaningfulData = true
                            events.events.append(contentsOf: results)
                        }
                    }

                default:
                    break
                }
            }
        }

        // Only mark the app as initialized if we found meaningful data
        if foundMeaningfulData {
            await TeamsStateManager.shared.setInitialized(forPid: params.appPid)
            Log.info("Teams parsing successful - found meaningful data, marking as initialized", category: .controlFlow)
        } else {
            Log.info("Teams parsing completed but no meaningful data found", category: .controlFlow)
            // Don't mark it as initialized yet
        }

        let result: ParseResult
        if events.events.isEmpty {
            result = ParseResult(
                conversationSummaries: conversationSummaries,
                activeConversation: activeConversation
            )
        } else {
            result = ParseResult(calendar: events)
        }

        return result
    }

    private func processTeamsList(
        _ element: ElementProtocol,
        deadline: Deadline
    ) async throws -> [ConversationSummary] {
        var conversations: [ConversationSummary] = []

        for try await item in ElementDepthFirstSequence(element: element, childType: .children) {
            if deadline.hasPassed { break }

            guard let title = try? await item.element.getAttributeValue(.title) as? String,
                  !title.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            if let conversation = await parseTeamsConversation(title) {
                conversations.append(conversation)
            }
        }

        return conversations
    }

    private func parseTeamsConversation(_ description: String) async -> ConversationSummary? {
        let cleanedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let unread = cleanedDescription.contains("unread")

        let channelPattern = #"^(?:Group chat\. )?(.+?) Last message:"#
        let channelRegex = try? NSRegularExpression(pattern: channelPattern, options: [])

        var channel: String?
        if let match = channelRegex?.firstMatch(
            in: cleanedDescription,
            options: [],
            range: NSRange(location: 0, length: cleanedDescription.utf16.count)
        ) {
            channel = (cleanedDescription as NSString).substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespaces)
        }

        let messagePattern = #"Last message: (.+?): (.*?) (?:On|At) (\d{1,2}/\d{1,2}|\d{1,2}:\d{2} (?:AM|PM))"#
        let messageRegex = try? NSRegularExpression(pattern: messagePattern, options: [])

        if let match = messageRegex?.firstMatch(
            in: cleanedDescription,
            options: [],
            range: NSRange(location: 0, length: cleanedDescription.utf16.count)
        ) {
            let sender = (cleanedDescription as NSString).substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespaces)
            let lastMessage = (cleanedDescription as NSString).substring(with: match.range(at: 2))
                .trimmingCharacters(in: .whitespaces)
            let lastMessageTime = (cleanedDescription as NSString).substring(with: match.range(at: 3))
                .trimmingCharacters(in: .whitespaces)

            return ConversationSummary(
                app: parsedApp.title,
                channel: channel,
                sender: sender,
                lastMessage: lastMessage,
                lastMessageTime: lastMessageTime,
                unread: unread
            )
        }

        return nil
    }

    private func processMessagesList(_ element: ElementProtocol, deadline: Deadline) async throws -> [Message] {
        var messages: [Message?] = []

        if let description = try? await element.getAttributeValue(.description) as? String,
           !description.trimmingCharacters(in: .whitespaces).isEmpty {
            let message = parseMessageDescription(description)
            messages.append(message)
        }
        return messages.compactMap { $0 }
    }

    private func parseMessageDescription(_ description: String) -> Message? {
        let pattern = #"^(.+?)(?: Sent)? (.+?) (\w+ \d{1,2}, \d{4} \d{1,2}:\d{2} (?:AM|PM))\.$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])

        if let match = regex?.firstMatch(
            in: description,
            options: [],
            range: NSRange(location: 0, length: description.utf16.count)
        ) {
            let sender = (description as NSString).substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespaces)
            let content = (description as NSString).substring(with: match.range(at: 2))
                .trimmingCharacters(in: .whitespaces)
            let timestring = (description as NSString).substring(with: match.range(at: 3))
                .trimmingCharacters(in: .whitespaces)

            return Message(
                sender: sender,
                content: content,
                timestamp: DateReformatter.reformatMessages(dateString: timestring), // Converts string to Date
                messageType: "chat",
                timestring: timestring
            )
        }

        return nil
    }

    private func processCalendarEvents(_ element: ElementProtocol, deadline: Deadline) async -> [CalendarEvent] {
        var events: [CalendarEvent] = []

        for try await item in ElementDepthFirstSequence(element: element, childType: .children) {
            if deadline.hasPassed { break }

            // Check AXDescription for event details
            if let description = try? await item.element.getAttributeValue(.description) as? String {
                if description.contains(","), description.contains(" to "), description.contains("organized by") {
                    if let event = parseEvent(description) {
                        events.append(event)
                    }
                }
            }
        }

        return events
    }

    private func parseEvent(_ description: String) -> CalendarEvent? {
        // Regex to extract event details
        let pattern =
            #"^(.*?), ((?:\w+ \d{1,2}, \d{4} \d{1,2}:\d{2} (?:AM|PM)) to (\d{1,2}:\d{2} (?:AM|PM))), location: (.*?), organized by (.*?),.*$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])

        if let match = regex?.firstMatch(
            in: description,
            options: [],
            range: NSRange(location: 0, length: description.utf16.count)
        ) {
            let title = (description as NSString).substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespaces)
            let dateTime = (description as NSString).substring(with: match.range(at: 2))
                .trimmingCharacters(in: .whitespaces)
            let rawLocation = (description as NSString).substring(with: match.range(at: 4))
                .trimmingCharacters(in: .whitespaces)
            let organizer = (description as NSString).substring(with: match.range(at: 5))
                .trimmingCharacters(in: .whitespaces)

            // Parse Location & Address
            let locationComponents = rawLocation.split(separator: ",", maxSplits: 1)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
            let locationName = locationComponents.first ?? "Unknown Location"
            let locationAddress = locationComponents.count > 1 ? locationComponents[1] : nil

            let location = CalendarLocation(name: locationName, address: locationAddress)
            return CalendarEvent(
                dateString: dateTime,
                title: title,
                location: location,
                organizer: organizer
            )
        }

        return nil
    }
}
