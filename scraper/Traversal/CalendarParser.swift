//
//  CalendarParser.swift
//  observer-lib
//
//  Created by Soroush Khanlou on 1/2/25.
//

import ApplicationServices
import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

public actor CalendarParser: CustomParser {
    public let parsedApp: ParseableApp = .calendar

    enum EventType { case allDay, regular }

    private lazy var monitoringService = MonitoringService()
    public init() {}

    public func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        var events = CalendarEvents(events: [])

        for try await element in ElementDepthFirstSequence(element: params.accessWindow).map(\.element) {
            if deadline.hasPassed { throw AccessError.timeout }

            do {
                if try await element.getAttributeValue(.roleDescription) as? String == "Event",
                   let description = try await element.getAttributeValue(.description) as? String {
                    let parsed = try self.parseEvent(description)
                    events.events.append(parsed)
                }

            } catch {
                Log.error("Error processing element", error: error)
            }
        }
        return ParseResult(calendar: events)
    }

    func parseEvent(_ description: String) throws -> CalendarEvent {
        // matches things like:

        // Christmas Day. December 25, 2024, All-Day
        // Testing at Shake Shack\n1333 Broadway, New York, NY  10018, United States. Starts on December 24, 2024 at
        // 12:15 PM and ends at 1:15 PM.

        let regex = /(.*?)( at (.*)\n(.+))?\. (.+)/
        let match = try regex.firstMatch(in: description)

        let location: CalendarLocation? = (match?.output.2 != nil || match?.output.3 != nil)
            ? CalendarLocation(
                name: (match?.output.3).map(String.init) ?? "",
                address: (match?.output.4).map(String.init)
            )
            : nil

        return CalendarEvent(
            dateString: (match?.output.5).map(String.init),
            title: (match?.output.1).map(String.init),
            location: location,
            organizer: nil
        )
    }
}
