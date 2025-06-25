import CoreFoundation

/// Wrapper around an event produced by the legacy consumer accessibility API.
public struct Event: Sendable {
    /// Event notification.
    public let notification: AccessNotification
    /// Element generating this event.
    public let subject: Element
    /// Event payload.
    public let payload: [AccessNotification.PayloadKey: Sendable]
}
