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
    
    /// Extract mentions from message content (enhanced for Slack patterns)
    static func extractMentions(from content: String) -> [String] {
        var mentions: [String] = []
        
        // Pattern 1: Standard @username mentions
        let mentionPattern = #"@([a-zA-Z0-9._-]+)"#
        if let regex = try? NSRegularExpression(pattern: mentionPattern) {
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            let matches = regex.matches(in: content, options: [], range: range)
            for match in matches {
                if let mentionRange = Range(match.range(at: 1), in: content) {
                    let mention = "@" + String(content[mentionRange])
                    mentions.append(mention)
                }
            }
        }
        
        // Pattern 2: Special mentions (@channel, @here, @everyone)
        let specialMentions = ["@channel", "@here", "@everyone"]
        for specialMention in specialMentions {
            if content.localizedCaseInsensitiveContains(specialMention) {
                mentions.append(specialMention)
            }
        }
        
        // Pattern 3: Display name mentions (sometimes Slack shows "John Doe" instead of @johndoe)
        let displayNameMentions = extractDisplayNameMentions(from: content)
        mentions.append(contentsOf: displayNameMentions)
        
        let finalMentions = Array(Set(mentions)) // Remove duplicates
        return finalMentions
    }
    
    /// Extract display name mentions from content (names that appear to be user mentions)
    private static func extractDisplayNameMentions(from content: String) -> [String] {
        var mentions: [String] = []
        
        // Pattern for common name formats that might be mentions in Slack
        // Look for capitalized words that could be names, but be conservative
        let namePatterns = [
            // Pattern 1: "Welcome Sofia" - single capitalized names in welcome contexts
            #"(?:welcome|hi|hello|thanks)\s+([A-Z][a-z]{2,15})(?:\s|$|[,.!])"#,
            
            // Pattern 2: "Thanks John" or "Great work Alice"
            #"(?:thanks|thank you|great work|nice job|well done)\s+([A-Z][a-z]{2,15})(?:\s|$|[,.!])"#,
            
            // Pattern 3: Names followed by specific patterns that suggest they're user references
            #"([A-Z][a-z]{2,15})\s+(?:is|has|will|was|did|said)"#,
            
            // Pattern 4: Greetings with names
            #"(?:^|\s)([A-Z][a-z]{2,15})(?:'s|,\s+(?:how|what|where|when))"#
        ]
        
        for pattern in namePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                for match in matches {
                    if let nameRange = Range(match.range(at: 1), in: content) {
                        let name = String(content[nameRange])
                        
                        // Additional validation - avoid common words that aren't names
                        if isLikelyUserName(name) {
                            mentions.append("@\(name.lowercased())")
                        }
                    }
                }
            }
        }
        
        return mentions
    }
    
    /// Check if a word is likely to be a user name vs a common word
    private static func isLikelyUserName(_ word: String) -> Bool {
        // Exclude common words that might be capitalized but aren't names
        let excludedWords = [
            "Today", "Yesterday", "Tomorrow", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
            "January", "February", "March", "April", "June", "July", "August", "September", "October", "November", "December",
            "Please", "Thanks", "Welcome", "Hello", "Great", "Nice", "Good", "Best", "Here", "There", "This", "That",
            "Team", "Everyone", "Someone", "Anyone", "Project", "Meeting", "Update", "Report", "File", "Document",
            "System", "Server", "Database", "Website", "Application", "Software", "Hardware", "Network"
        ]
        
        return !excludedWords.contains(word) && 
               word.count >= 3 && 
               word.count <= 15 &&
               word.first?.isUppercase == true
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
    
    /// Print element attributes for debugging (disabled in production)
    static func debugElement(_ element: Element, label: String = "Element") {
        // Debug logging disabled
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
            // Error in debug summary generation
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