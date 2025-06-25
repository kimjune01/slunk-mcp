//
// Copyright GenOS. All rights Reserved
//

import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

public actor GoogleMeetParser {
    var meetingID: String?

    static let identifier: String = "\(GoogleMeetParser.self)"

    func parse(
        _ params: WindowParams,
        deadline: Deadline
    ) async throws -> ParseResult {
        Log.debug("\(GoogleMeetParser.identifier): \(#function) Called")
        // swiftlint:disable:next opening_brace
        let meetingIDPattern = /^[a-z]{3}-[a-z]{4}-[a-z]{3}$/

        let elementSequence = ElementDepthFirstSequence(element: params.accessWindow, childType: .children)

        for try await item in elementSequence {
            if deadline.hasPassed { break }

            do {
                let role = try await item.element.getAttributeValue(.role) as? Role
                switch role {
                case .staticText:
                    if let textValue = try? await item.element.getValue(),
                       let meetingID = try? textValue.firstMatch(of: meetingIDPattern) {
                        self.meetingID = meetingID.base
                    }
                default:
                    break
                }
            } catch {
                Log.error("\(GoogleMeetParser.identifier): \(#function)", error: error)
            }
        }

        if let meetingID {
            return ParseResult(meeting: Meeting(name: "Google Meet - \(meetingID)"))
        }

        return .empty
    }
}
