//
//  OutlookParser.swift
//  observer-lib
//
//  Created by Vincent Villalta on 3/18/25.
//

import ApplicationServices
import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

actor OutlookParser: CustomParser {
    public let parsedApp: ParseableApp = .microsoftoutlook

    public init() {}

    func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        Log.debug(
            """
            OutlookParser.parse() called
            =======================================================
            """,
            category: .controlFlow
        )

        let elementSequence = ElementDepthFirstSequence(element: params.accessWindow, childType: .children)
        var activeConversation = Conversation(
            app: parsedApp.title,
            channel: "",
            messages: []
        )
        var calendar = CalendarEvents(events: [])

        for try await item in elementSequence {
            if deadline.hasPassed { break }

            if let role = try? await item.element.getAttributeValue(.role) as? Role {
                switch role {
                case .list:
                    if let description = try? await item.element.getAttributeValue(.description) as? String {
                        debugPrint(description)
                    }
                case .group:
                    let description = try? await item.element.getAttributeValue(.description) as? String
                    if let email = parseEmail(from: description) {
                        activeConversation.messages.append(email)
                    }

                    let results = try await processCalendarEvents(item.element, deadline: deadline)
                    calendar.events.append(contentsOf: results)
                case .cell:
                    if let description = try? await item.element.getAttributeValue(.description) as? String {
                        if let email = parseEmail(from: description) {
                            activeConversation.messages.append(email)
                            Log.info("✅ Extracted Email", category: .controlFlow)
                        }
                    }
                default:
                    break
                }
            }
        }

        if !calendar.events.isEmpty {
            return ParseResult(calendar: calendar)
        } else {
            return ParseResult(activeConversations: [activeConversation])
        }
    }

    func parseEmail(from description: String?) -> Message? {
        guard let description else { return nil }

        let regexPattern =
            "Sender:\\s*(.*?),\\s*Subject:\\s*(.*?),\\s*(\\d{1,2}\\/\\d{1,2}\\/\\d{2,4}),\\s*Message preview:\\s*(.*)"
        let regex = try? NSRegularExpression(pattern: regexPattern, options: [])

        guard let match = regex?.firstMatch(
            in: description,
            options: [],
            range: NSRange(location: 0, length: description.utf16.count)
        ) else {
            return nil
        }

        func extractMatch(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: description) else { return nil }
            return String(description[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let sender = extractMatch(1) ?? "Unknown"
        let subject = extractMatch(2) ?? "Unknown"
        let timestamp = extractMatch(3) ?? "Unknown"
        let preview = extractMatch(4) ?? ""

        return Message(
            sender: sender,
            content: "\(subject) - \(preview)",
            timestamp: DateReformatter.reformatMessages(dateString: timestamp),
            messageType: "email",
            timestring: timestamp
        )
    }

    private func processCalendarEvents(_ element: ElementProtocol, deadline: Deadline) async throws -> [CalendarEvent] {
        var events: [CalendarEvent] = []

        for try await item in ElementDepthFirstSequence(element: element, childType: .children) {
            if deadline.hasPassed { break }
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

    func parseEvent(_ description: String) -> CalendarEvent? {
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

            let locationComponents = rawLocation.split(separator: ",", maxSplits: 1)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
            let locationName = locationComponents.first ?? "Unknown Location"
            let locationAddress = locationComponents.count > 1 ? locationComponents[1] : nil

            let location = CalendarLocation(name: locationName, address: locationAddress)
            return CalendarEvent(
                dateString: dateTime,
                title: title,
                location: location,
                organizer: nil
            )
        }

        return nil
    }
}
