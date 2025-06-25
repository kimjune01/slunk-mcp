@preconcurrency import ApplicationServices

/// Throwable error values that can also be returned as data from the accessibility infrastructure.
public struct AccessError: Error, Identifier {
    public let rawValue: AXError.RawValue

    public static let success = Self(.success)
    public static let systemFailure = Self(.failure)
    public static let illegalArgument = Self(.illegalArgument)
    public static let invalidElement = Self(.invalidUIElement)
    public static let invalidObserver = Self(.invalidUIElementObserver)
    public static let timeout = Self(.cannotComplete)
    public static let attributeUnsupported = Self(.attributeUnsupported)
    public static let actionUnsupported = Self(.actionUnsupported)
    public static let notificationUnsupported = Self(.notificationUnsupported)
    public static let notImplemented = Self(.notImplemented)
    public static let notificationAlreadyRegistered = Self(.notificationAlreadyRegistered)
    public static let notificationNotRegistered = Self(.notificationNotRegistered)
    public static let apiDisabled = Self(.apiDisabled)
    public static let noValue = Self(.noValue)
    public static let parameterizedAttributeUnsupported = Self(.parameterizedAttributeUnsupported)
    public static let notEnoughPrecision = Self(.notEnoughPrecision)

    /// Creates a new accessibility error from a legacy error value.
    /// - Parameter error: Legacy error value.
    init(_ error: AXError) {
        self.rawValue = error.rawValue
    }
}

extension AccessError: CustomStringConvertible {
    public var description: String {
        return switch self {
        case .success: "Success"
        case .systemFailure: "System failure"
        case .illegalArgument: "Illegal argument"
        case .invalidElement: "Invalid element"
        case .invalidObserver: "Invalid observer"
        case .timeout: "Request timed out"
        case .attributeUnsupported: "Attribute unsupported"
        case .actionUnsupported: "Action unsupported"
        case .notificationUnsupported: "Notification unsupported"
        case .parameterizedAttributeUnsupported: "Parameterized attribute unsupported"
        case .notImplemented: "Accessibility not supported"
        case .notificationAlreadyRegistered: "Notification already registered"
        case .notificationNotRegistered: "Notification not registered"
        case .apiDisabled: "Accessibility API disabled"
        case .noValue: "No value"
        case .notEnoughPrecision: "Not enough precision"
        default: "Unknown error value: \(rawValue)"
        }
    }
}

extension AccessError: LocalizedError {
    public var errorDescription: String? {
        return String(describing: self)
    }
}