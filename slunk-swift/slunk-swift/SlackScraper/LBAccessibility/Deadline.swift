import Foundation

public struct Deadline: Sendable, Equatable {
    public let startDate: Date
    public let length: TimeInterval

    public var endDate: Date {
        startDate.addingTimeInterval(length)
    }

    public var hasPassed: Bool {
        endDate <= .now
    }

    public var timeRemaining: TimeInterval {
        max(0, endDate.timeIntervalSince(Date()))
    }

    public static func fromNow(duration: TimeInterval) -> Self {
        Self(startDate: .now, length: duration)
    }

    public static var never: Deadline { .init(startDate: .now, length: 1_000_000_000) }

    public static func ==(lhs: Deadline, rhs: Deadline) -> Bool {
        lhs.startDate == rhs.startDate && lhs.length == rhs.length
    }
}