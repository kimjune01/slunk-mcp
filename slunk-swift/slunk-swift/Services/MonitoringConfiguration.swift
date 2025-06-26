import Foundation

/// Configuration for Slack monitoring behavior
public struct MonitoringConfiguration {
    // Polling intervals
    public let pollIntervalActive: TimeInterval
    public let pollIntervalBackground: TimeInterval
    public let pollIntervalInactive: TimeInterval
    
    // Retry settings
    public let retryDelay: TimeInterval
    public let maxRetries: Int
    
    // Feature flags
    public var contentParsingEnabled: Bool
    public var backgroundMonitoringEnabled: Bool
    
    // Database settings
    public let retentionPeriodMonths: Int
    public let maxExtractionHistory: Int
    
    public static let `default` = MonitoringConfiguration(
        pollIntervalActive: 5.0,
        pollIntervalBackground: 10.0,
        pollIntervalInactive: 30.0,
        retryDelay: 5.0,
        maxRetries: 3,
        contentParsingEnabled: false,
        backgroundMonitoringEnabled: true,
        retentionPeriodMonths: 2,
        maxExtractionHistory: 10
    )
}