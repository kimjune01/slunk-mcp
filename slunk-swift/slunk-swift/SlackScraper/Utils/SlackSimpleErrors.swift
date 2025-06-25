import Foundation

/// Simple error type for SlackScraper
public enum SlackScraperError: Error, LocalizedError {
    case invalidData(String)
    case serviceNotRunning(String)
    case configurationError(String)
    case unexpectedError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidData(let details):
            return "Invalid data: \(details)"
        case .serviceNotRunning(let service):
            return "Service not running: \(service)"
        case .configurationError(let details):
            return "Configuration error: \(details)"
        case .unexpectedError(let details):
            return "Unexpected error: \(details)"
        }
    }
}