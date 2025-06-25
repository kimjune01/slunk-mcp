import Foundation

// MARK: - Core Protocols

/// Protocol for objects that can be tracked and identified uniquely
public protocol Identifiable {
    associatedtype ID: Hashable
    var id: ID { get }
}

/// Protocol for objects that can provide timestamped data
public protocol Timestamped {
    var timestamp: Date { get }
}

/// Protocol for objects that can be serialized to/from persistent storage
public protocol Persistable: Codable, Identifiable {
    var createdAt: Date { get }
    var updatedAt: Date { get }
}

/// Protocol for objects that can be converted to documents for vector storage
public protocol DocumentConvertible {
    func toDocument() -> SlackDocument
}

/// Protocol for objects that can be validated
public protocol Validatable {
    func validate() throws
}

/// Protocol for objects that support metadata
public protocol MetadataSupporting {
    associatedtype MetadataType: Codable
    var metadata: MetadataType? { get }
}

// MARK: - Slack-Specific Protocols

/// Protocol for Slack-related objects that have workspace context
public protocol SlackWorkspaceScoped {
    var workspace: String { get }
}

/// Protocol for Slack-related objects that have channel context
public protocol SlackChannelScoped: SlackWorkspaceScoped {
    var channel: String { get }
}

/// Protocol for Slack content that can be processed
public protocol SlackContentProcessable: Timestamped, Validatable {
    var content: String { get }
    var sender: String { get }
}

/// Protocol for objects that can be deduplicated
public protocol Deduplicatable {
    var deduplicationKey: String { get }
}

// MARK: - Service Protocols

/// Protocol for services that can be started and stopped
public protocol ServiceLifecycle {
    var isRunning: Bool { get }
    func start() async throws
    func stop() async
}

/// Protocol for services that can handle configuration
public protocol Configurable {
    associatedtype ConfigurationType
    func configure(with config: ConfigurationType) throws
}

/// Protocol for services that provide health checking
public protocol HealthCheckable {
    func healthCheck() async -> HealthStatus
}

/// Protocol for services that can be observed for status changes
public protocol Observable: AnyObject {
    associatedtype StatusType
    func addObserver(_ observer: @escaping (StatusType) -> Void)
    func removeObserver()
}

// MARK: - Processing Protocols

/// Protocol for content processors
public protocol ContentProcessor {
    associatedtype InputType
    associatedtype OutputType
    func process(_ input: InputType) async throws -> OutputType
}

/// Protocol for content filters
public protocol ContentFilter {
    associatedtype ContentType
    func shouldProcess(_ content: ContentType) -> Bool
}

/// Protocol for content transformers
public protocol ContentTransformer {
    associatedtype InputType
    associatedtype OutputType
    func transform(_ input: InputType) throws -> OutputType
}

// MARK: - Supporting Types

public struct HealthStatus: Codable, Equatable {
    public let isHealthy: Bool
    public let message: String?
    public let timestamp: Date
    public let details: [String: String]?
    
    public init(isHealthy: Bool, message: String? = nil, details: [String: String]? = nil) {
        self.isHealthy = isHealthy
        self.message = message
        self.timestamp = Date()
        self.details = details
    }
    
    public static let healthy = HealthStatus(isHealthy: true, message: "Service is healthy")
    
    public static func unhealthy(_ message: String, details: [String: String]? = nil) -> HealthStatus {
        return HealthStatus(isHealthy: false, message: message, details: details)
    }
}