import Foundation
import ApplicationServices

// MARK: - Slack Parsing Helpers

/// Utility functions and helpers for Slack parsing operations
public struct SlackParsingHelpers {
    
    // MARK: - Validation Helpers
    
    /// Validate that a string is a valid sender name
    static func isValidSender(_ sender: String?) -> Bool {
        guard let sender = sender, !sender.isEmpty else { return false }
        
        // Filter out buttons that are clearly not senders
        let invalidSenderKeywords = ["replies", "reaction", "thread", "edited", "emoji", "add", "remove"]
        
        for keyword in invalidSenderKeywords {
            if sender.lowercased().contains(keyword) {
                return false
            }
        }
        
        // Check length - usernames shouldn't be too long
        return sender.count <= 100
    }
    
    /// Validate that a string is valid message content
    static func isValidMessageContent(_ content: String?) -> Bool {
        guard let content = content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else { return false }
        
        // Filter out system messages or noise
        let systemMessageKeywords = ["joined the channel", "left the channel", "set the channel topic", "uploaded a file"]
        
        for keyword in systemMessageKeywords {
            if content.lowercased().contains(keyword) {
                return false
            }
        }
        
        return true
    }
    
    /// Check if a string looks like a username pattern
    static func looksLikeUsername(_ text: String) -> Bool {
        // Check common username patterns
        let usernamePattern = #"^[a-zA-Z0-9._-]+$"#
        let regex = try? NSRegularExpression(pattern: usernamePattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let regex = regex {
            return regex.firstMatch(in: text, options: [], range: range) != nil
        }
        
        // Fallback checks
        return !text.contains(":") && 
               text.count > 1 && 
               text.count < 50 &&
               !text.contains(" ")
    }
    
    // MARK: - Text Processing Helpers
    
    /// Clean and normalize text content
    static func cleanText(_ text: String) -> String {
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n+"#, with: "\n", options: .regularExpression)
    }
    
    /// Extract mentions from message content
    static func extractMentions(from content: String) -> [String] {
        let mentionPattern = #"@([a-zA-Z0-9._-]+)"#
        let regex = try? NSRegularExpression(pattern: mentionPattern)
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        
        var mentions: [String] = []
        
        if let regex = regex {
            let matches = regex.matches(in: content, options: [], range: range)
            for match in matches {
                if let mentionRange = Range(match.range(at: 1), in: content) {
                    mentions.append(String(content[mentionRange]))
                }
            }
        }
        
        return mentions
    }
    
    /// Extract channel references from message content
    static func extractChannelReferences(from content: String) -> [String] {
        let channelPattern = #"#([a-zA-Z0-9._-]+)"#
        let regex = try? NSRegularExpression(pattern: channelPattern)
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        
        var channels: [String] = []
        
        if let regex = regex {
            let matches = regex.matches(in: content, options: [], range: range)
            for match in matches {
                if let channelRange = Range(match.range(at: 1), in: content) {
                    channels.append(String(content[channelRange]))
                }
            }
        }
        
        return channels
    }
    
    // MARK: - Element Type Helpers
    
    /// Check if an element looks like a message container
    static func isMessageContainer(_ element: Element) -> Bool {
        // Check for common message container indicators
        if let roleDescription = try? element.getAttributeValue("AXRoleDescription") as? String {
            return roleDescription == "message" || roleDescription.contains("message")
        }
        
        // Check for message-related classes
        if let className = try? element.getAttributeValue("AXDOMClassList") as? [String] {
            for cls in className {
                if cls.contains("message") || cls.contains("msg") {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Check if an element looks like a sender element
    static func isSenderElement(_ element: Element) -> Bool {
        // Check role - senders are often buttons or links
        if let role = try? element.getAttributeValue(.role) as? Role {
            if role == .button || role == .link {
                // Additional validation for sender-like content
                if let value = try? element.getValue() {
                    return isValidSender(value) && looksLikeUsername(value)
                }
                if let title = try? element.getAttributeValue(.title) as? String {
                    return isValidSender(title) && looksLikeUsername(title)
                }
            }
        }
        
        return false
    }
    
    // MARK: - Debug Helpers
    
    /// Print element attributes for debugging
    static func debugElement(_ element: Element, label: String = "Element") {
        print("🐛 Debug \(label):")
        
        let attributes: [Attribute] = [.role, .title, .description, .value, .help]
        for attr in attributes {
            if let value = try? element.getAttributeValue(attr) {
                print("   \(attr): \(value)")
            }
        }
        
        // Try to get children count
        if let children = try? element.getChildren() {
            print("   children: \(children.count)")
        }
        
        // Try to get class list
        if let classList = try? element.getAttributeValue("AXDOMClassList") as? [String] {
            print("   classes: \(classList.joined(separator: ", "))")
        }
    }
    
    /// Create a summary of parsed content for debugging
    static func createDebugSummary(
        workspace: String?,
        channel: String?,
        messages: [SlackMessage]
    ) -> String {
        var summary = "🐛 Parsing Debug Summary:\n"
        summary += "  Workspace: '\(workspace ?? "nil")'\n"
        summary += "  Channel: '\(channel ?? "nil")'\n"
        summary += "  Messages: \(messages.count)\n"
        
        if !messages.isEmpty {
            summary += "  Sample messages:\n"
            for (index, message) in messages.prefix(3).enumerated() {
                let preview = String(message.content.prefix(50))
                summary += "    \(index + 1). \(message.sender): \(preview)...\n"
            }
        }
        
        return summary
    }
    
    // MARK: - Performance Helpers
    
    /// Create optimized matchers for common Slack elements
    static func createOptimizedMatchers() -> (
        messageContainer: ElementMatcher,
        senderButton: ElementMatcher,
        contentText: ElementMatcher,
        timestampLink: ElementMatcher
    ) {
        let messageContainer = Matchers.any([
            Matchers.hasClassContaining("message"),
            Matchers.hasClassContaining("msg")
        ])
        
        let senderButton = Matchers.all([
            Matchers.hasRole(.button),
            Matchers.not(Matchers.hasClassContaining("reaction")),
            Matchers.not(Matchers.hasClassContaining("thread"))
        ])
        
        let contentText = Matchers.hasRole(.staticText)
        
        let timestampLink = Matchers.hasRole(.link)
        
        return (messageContainer, senderButton, contentText, timestampLink)
    }
    
    // MARK: - Error Handling Helpers
    
    /// Handle common parsing errors gracefully
    static func handleParsingError(
        _ error: Error,
        context: String,
        element: Element?
    ) -> String {
        let errorMessage = "❌ Parsing error in \(context): \(error.localizedDescription)"
        
        if let element = element {
            print(errorMessage)
            debugElement(element, label: "Failed Element")
        }
        
        return errorMessage
    }
}

// MARK: - Extensions

extension Element {
    /// Convenience method to safely get string value
    func getSafeStringValue() -> String? {
        return try? getValue()
    }
    
    /// Convenience method to safely get title
    func getSafeTitle() -> String? {
        return try? getAttributeValue(.title) as? String
    }
    
    /// Convenience method to safely get description
    func getSafeDescription() -> String? {
        return try? getAttributeValue(.description) as? String
    }
    
    /// Check if element has any of the specified classes
    func hasAnyClass(_ classes: [String]) -> Bool {
        guard let classList = try? getAttributeValue("AXDOMClassList") as? [String] else {
            return false
        }
        
        return classes.contains { targetClass in
            classList.contains { elementClass in
                elementClass.contains(targetClass)
            }
        }
    }
}