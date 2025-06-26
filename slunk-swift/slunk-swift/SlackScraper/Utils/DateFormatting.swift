import Foundation

/// Thread-safe date formatter for ISO8601 dates used in Slack message processing
public final class SendableISO8601DateFormatter: @unchecked Sendable {
    private let formatter: ISO8601DateFormatter
    private let queue = DispatchQueue(label: "com.slunk.dateformatter")
    
    public init() {
        self.formatter = ISO8601DateFormatter()
        self.formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    
    public func string(from date: Date) -> String {
        return queue.sync {
            formatter.string(from: date)
        }
    }
    
    public func date(from string: String) -> Date? {
        return queue.sync {
            formatter.date(from: string)
        }
    }
}

/// Utility for reformatting various Slack timestamp formats
public struct SlackDateReformatter: Sendable {
    private let iso8601Formatter = SendableISO8601DateFormatter()
    
    public init() {}
    
    /// Convert various Slack timestamp formats to ISO8601 string
    public func reformatTimestamp(_ timestamp: String) -> String? {
        // Try common Slack timestamp formats
        let formats = [
            "yyyy-MM-dd HH:mm",
            "MMM dd, yyyy",
            "MMM dd",
            "h:mm a",
            "h:mm:ss a",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ"
        ]
        
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            
            if let date = formatter.date(from: timestamp) {
                return iso8601Formatter.string(from: date)
            }
        }
        
        // Try parsing Unix timestamp (common in Slack APIs)
        if let unixTimestamp = Double(timestamp) {
            let date = Date(timeIntervalSince1970: unixTimestamp)
            return iso8601Formatter.string(from: date)
        }
        
        return nil
    }
    
    /// Convert timestamp string to Date object
    public func parseTimestamp(_ timestamp: String) -> Date? {
        if let reformatted = reformatTimestamp(timestamp) {
            return iso8601Formatter.date(from: reformatted)
        }
        return nil
    }
    
    /// Extract relative time information (like "2 minutes ago") to approximate timestamp
    public func parseRelativeTime(_ relativeTime: String) -> Date? {
        let now = Date()
        let lowercased = relativeTime.lowercased()
        
        // Extract number from string
        let components = lowercased.components(separatedBy: .whitespaces)
        guard let numberString = components.first,
              let number = Int(numberString) else {
            return nil
        }
        
        // Determine time unit
        let timeInterval: TimeInterval
        if lowercased.contains("second") {
            timeInterval = -Double(number)
        } else if lowercased.contains("minute") {
            timeInterval = -Double(number * 60)
        } else if lowercased.contains("hour") {
            timeInterval = -Double(number * 3600)
        } else if lowercased.contains("day") {
            timeInterval = -Double(number * 86400)
        } else if lowercased.contains("week") {
            timeInterval = -Double(number * 604800)
        } else if lowercased.contains("month") {
            timeInterval = -Double(number * 2592000) // Approximate
        } else if lowercased.contains("year") {
            timeInterval = -Double(number * 31536000) // Approximate
        } else {
            return nil
        }
        
        return now.addingTimeInterval(timeInterval)
    }
}