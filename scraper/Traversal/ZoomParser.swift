//
//  ZoomParser.swift
//  observer-lib
//
//  Created by Vincent Villalta on 5/1/25.
//

import Foundation
import LBAccessibility
import LBDataModels
import LBMeetingObserver

public actor ZoomParser: MeetingAppParser {
    public let appName: String = "Zoom"

    /// Zoom does not expose the meeting id on the UI (unless the share meeting view is shown,
    /// returning a nil meetingId to allow the MeetingObserver to use the meeting id returned by the API
    public let meetingId: String? = nil

    public func getParticipants(from root: ElementProtocol) async -> [MeetingParticipant] {
        do {
            return try await ElementDepthFirstSequence(element: root)
                .map(\.element)
                .filter { element in
                    if let role = try? await element.getAttributeValue(.role) as? Role {
                        return role.description == "Video render"
                    }
                    return false
                }
                .compactMap { element in
                    let description = try await element.getAttributeValue(.description) as? String ?? ""
                    guard let name = description.split(separator: ",").first?.trimmingCharacters(in: .whitespaces),
                          !name.isEmpty else { return nil }

                    let isUnmuted = description.localizedCaseInsensitiveContains("unmuted")

                    return MeetingParticipant(
                        name: name,
                        isMe: false,
                        isMeetingHost: false,
                        isMuted: !isUnmuted,
                        isSpeaking: isUnmuted,
                        isPresenting: false
                    )
                }
                .collect()
        } catch {
            return []
        }
    }
    
    public func getCurrentSpeakers(from root: ElementProtocol) async -> [MeetingParticipant] {
        return await getParticipants(from: root).filter { $0.isSpeaking }
    }
    
    public func getPresentingParticipant(from root: ElementProtocol) async -> MeetingParticipant? {
        /// TODO
        return nil
    }
    
    public func isMeetingRecording(from root: ElementProtocol) async -> Bool {
        /// TODO
        return false
    }
    
    public func hasMeetingStarted(from root: ElementProtocol) async -> Bool {
        do {
            for await wrapper in ElementDepthFirstSequence(element: root) {
                let element = wrapper.element

                // Look for AXWindow with AXTitle == "Zoom Meeting"
                if let role = try? await element.getAttributeValue(.role) as? Role,
                   role.description == "AXWindow",
                   let title = try? await element.getAttributeValue(.title) as? String,
                   title.contains("Zoom Meeting") {
                    return true
                }

                // Fallback: Look for description mentioning a Zoom Meeting
                if let role = try? await element.getAttributeValue(.role) as? Role,
                   role.description.localizedCaseInsensitiveContains("in a zoom meeting") {
                    return true
                }
            }
        } catch {
            return false
        }

        return false
    }
    
    public func didMeetingEnd(from root: ElementProtocol) async -> Bool {
        /// TODO
        return await !hasMeetingStarted(from: root)
    }
    
    public func isMeetingRunning(from root: ElementProtocol) async -> Bool {
        /// TODO
        return true
    }
    

}
