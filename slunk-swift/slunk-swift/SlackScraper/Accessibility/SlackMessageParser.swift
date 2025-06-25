import Foundation
import ApplicationServices

// MARK: - Slack Message Parser

/// Handles parsing individual messages from Slack's accessibility tree
actor SlackMessageParser {
    
    // MARK: - Message Parsing
    
    /// Parse messages from content list using LBAccessibility
    func parseMessagesFromContentList(_ contentList: Element) async throws -> [SlackMessage] {
        print("🔍 SlackMessageParser: Parsing messages from content list...")
        
        // Check if this is a thread sidebar for processing context
        let _ = (try? contentList.getAttributeValue(.description) as? String)?.contains("Thread") ?? false
        
        // Get all child elements that might be messages
        guard let children = try contentList.getChildren() else {
            print("❌ SlackMessageParser: No children found in content list")
            return []
        }
        
        print("🔍 SlackMessageParser: Found \(children.count) child elements")
        
        var messages: [SlackMessage] = []
        
        for (index, child) in children.enumerated() {
            if let childElement = child as? Element,
               let message = try await parseMessageElement(childElement, index: index) {
                messages.append(message)
            }
        }
        
        // Sort by timestamp (newest first)
        return messages.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Parse individual message element
    func parseMessageElement(_ element: Element, index: Int) async throws -> SlackMessage? {
        // Parse message element structure
        
        // Look for message structure - messages often have specific role descriptions
        guard let children = try element.getChildren(), !children.isEmpty else {
            return nil
        }
        
        // Find the main message group
        guard let messageGroup = children.first as? Element else { return nil }
        
        // Check if this looks like a message (has role description "message")
        if let roleDescription = try messageGroup.getAttributeValue("AXRoleDescription") as? String,
           roleDescription == "message" {
            
            return try await extractMessageFromGroup(messageGroup, index: index)
        }
        
        return nil
    }
    
    /// Extract message content from message group element
    func extractMessageFromGroup(_ messageGroup: Element, index: Int) async throws -> SlackMessage? {
        // Extract message from group structure
        
        guard let groupChildren = try messageGroup.getChildren(),
              let mainGroup = groupChildren.first as? Element else {
            return nil
        }
        
        guard let mainChildren = try mainGroup.getChildren() else {
            return nil
        }
        
        var sender: String?
        var timestamp: Date?
        
        // Look for sender in main children
        
        // Extract sender and timestamp from main children
        for (_, child) in mainChildren.enumerated() {
            if let childElement = child as? Element {
                // Try multiple attributes for sender name
                if let role = try? childElement.getAttributeValue(.role) as? Role {
                    
                    if role == .button && sender == nil {
                        // Sender name is often in a button element
                        let buttonTitle = try childElement.getAttributeValue(.title) as? String
                        let buttonValue = try childElement.getValue()
                        let potentialSender = buttonTitle ?? buttonValue
                        
                        // Filter out buttons that are clearly not senders (but keep reply buttons for thread detection)
                        if let s = potentialSender, 
                           !s.contains("reaction") && 
                           !s.contains("edited") &&
                           !s.lowercased().contains("reply") &&
                           !s.lowercased().contains("replies") &&
                           !s.isEmpty {
                            sender = s
                            print("   ✅ Found sender from button: '\(s)'")
                        }
                    } else if role == .link {
                        // Could be sender or timestamp
                        let linkText = try childElement.getValue() ?? ""
                        let linkDesc = try childElement.getAttributeValue(.description) as? String ?? ""
                        
                        // Check if it's a timestamp
                        if linkDesc.contains("at ") {
                            timestamp = parseSlackTimestamp(from: linkDesc)
                        } else if sender == nil && !linkText.isEmpty {
                            // Might be the sender name as a link
                            sender = linkText
                            print("   ✅ Found sender from link: '\(sender ?? "")'")
                        }
                    } else if role == .staticText && sender == nil {
                        // Sometimes sender is just static text
                        if let text = try childElement.getValue(), !text.isEmpty {
                            // Check if this looks like a username
                            if !text.contains(":") && text.count < 50 {
                                sender = text
                                print("   ✅ Found sender from static text: '\(sender ?? "")'")
                            }
                        }
                    }
                }
            }
        }
        
        // If still no sender, look deeper in the tree
        if sender == nil {
            print("   🔍 No sender found in direct children, searching deeper...")
            
            // Look for any element with a reasonable username
            let usernameMatcher = Matchers.any([
                Matchers.hasRole(.button),
                Matchers.hasRole(.link),
                Matchers.hasClassContaining("author"),
                Matchers.hasClassContaining("sender"),
                Matchers.hasClassContaining("username")
            ])
            
            if let senderElement = try await mainGroup.findElement(
                matching: usernameMatcher,
                maxDepth: 5,
                deadline: Deadline.fromNow(duration: 1.0)
            ) {
                sender = try? senderElement.getValue()
                if sender == nil {
                    sender = try? senderElement.getAttributeValue(.title) as? String
                }
                if let s = sender {
                    print("   ✅ Found sender via deep search: '\(s)'")
                }
            }
        }
        
        // Extract message content with thread detection using tree traversal
        let contentResult = try await extractMessageContentWithThreads(from: mainGroup)
        let content = contentResult.content
        
        // If we have content but no sender, use a placeholder
        if let content = content, !content.isEmpty, sender == nil {
            sender = "Unknown User"
            print("   ⚠️ Using placeholder sender for message with content")
        }
        
        guard let content = content, !content.isEmpty,
              let sender = sender else {
            print("❌ SlackMessageParser: Missing required message data (content: \(content?.isEmpty ?? true), sender: \(sender == nil))")
            return nil
        }
        
        print("✅ SlackMessageParser: Extracted message from \(sender): \(String(content.prefix(50)))")
        
        return SlackMessage(
            timestamp: timestamp ?? Date(),
            sender: sender,
            content: content,
            messageType: .regular
        )
    }
    
    /// Extract text content from element using LBAccessibility tree traversal
    func extractMessageContent(from element: Element) async throws -> String? {
        // Use LBAccessibility tree value collection
        let content = try await element.collectTreeValues(
            matching: Matchers.hasRole(.staticText),
            maxDepth: 10,
            separator: " "
        )
        
        return content?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Enhanced Thread Content Detection
    
    /// Result structure for enhanced content extraction with thread info
    /// Based on reference SlackParser.swift:295-300
    private struct ContentResult {
        let content: String?
        let isThread: Bool
        let threadInfo: [String]
    }
    
    /// Extract message content with thread detection
    /// Based on reference SlackParser.swift:302-390
    private func extractMessageContentWithThreads(from element: Element) async throws -> ContentResult {
        var threadInfo: [String] = []
        var contentParts: [String] = []
        var hasThreadButtons = false
        
        // Traverse the element tree to find thread indicators and content
        try await traverseForThreadContent(element, threadInfo: &threadInfo, contentParts: &contentParts, hasThreadButtons: &hasThreadButtons)
        
        let mainContent = contentParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Enhance content with thread information if present
        let finalContent: String
        if !threadInfo.isEmpty {
            finalContent = "\(mainContent) (\(threadInfo.joined(separator: ", ")))"
        } else {
            finalContent = mainContent
        }
        
        return ContentResult(
            content: finalContent.isEmpty ? nil : finalContent,
            isThread: !threadInfo.isEmpty,
            threadInfo: threadInfo
        )
    }
    
    /// Recursively traverse element tree to collect thread info and content
    /// Based on reference SlackParser.swift:317-355 rule patterns
    private func traverseForThreadContent(
        _ element: Element,
        threadInfo: inout [String],
        contentParts: inout [String],
        hasThreadButtons: inout Bool
    ) async throws {
        
        // Check current element for thread indicators
        if let role = try? element.getAttributeValue(.role) as? Role {
            
            // Thread button detection (reference lines 318-324)
            if role == .button {
                if let title = try? element.getAttributeValue(.title) as? String {
                    if title.lowercased().contains("reply") || title.lowercased().contains("replies") {
                        threadInfo.append(title)
                        hasThreadButtons = true
                        return // Don't process children of thread buttons
                    }
                }
            }
            
            // Thread group detection (reference lines 332-338)
            else if role == .group {
                // Check if this group contains "Last reply" text
                if let children = try? element.getChildren() {
                    for child in children {
                        if let childElement = child as? Element,
                           let value = try? childElement.getValue(),
                           value.contains("Last reply") {
                            threadInfo.append(value)
                            return // Don't process other children
                        }
                    }
                }
            }
            
            // Static text content collection (reference lines 339-354)
            else if role == .staticText {
                if let value = try? element.getValue(),
                   !value.isEmpty,
                   value != "\u{00A0}\u{00A0}" { // Skip non-breaking spaces
                    
                    // If we have thread buttons, collect as thread info
                    if hasThreadButtons {
                        threadInfo.append(value)
                    } else {
                        // Otherwise collect as regular content
                        contentParts.append(value)
                    }
                    return // Don't traverse children of text elements
                }
            }
        }
        
        // Recursively traverse children
        if let children = try? element.getChildren() {
            for child in children {
                if let childElement = child as? Element {
                    try await traverseForThreadContent(childElement, threadInfo: &threadInfo, contentParts: &contentParts, hasThreadButtons: &hasThreadButtons)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Parse Slack timestamp from description string
    private func parseSlackTimestamp(from description: String) -> Date? {
        // Handle formats like "Today at 6:47:45 AM" or "Yesterday at 2:30 PM"
        if let atRange = description.range(of: " at ") {
            let timeString = String(description[atRange.upperBound...])
            
            // Try different time formats
            let formatters = [
                ("h:mm:ss a", DateFormatter()),  // 6:47:45 AM
                ("h:mm a", DateFormatter()),      // 2:30 PM
                ("HH:mm:ss", DateFormatter()),    // 18:47:45
                ("HH:mm", DateFormatter())        // 18:47
            ]
            
            for (format, formatter) in formatters {
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US")
                if let date = formatter.date(from: timeString) {
                    // Combine with today's date
                    let calendar = Calendar.current
                    let now = Date()
                    
                    if description.hasPrefix("Today") {
                        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
                        return calendar.date(bySettingHour: components.hour ?? 0,
                                           minute: components.minute ?? 0,
                                           second: components.second ?? 0,
                                           of: now)
                    } else if description.hasPrefix("Yesterday") {
                        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
                        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
                            return calendar.date(bySettingHour: components.hour ?? 0,
                                               minute: components.minute ?? 0,
                                               second: components.second ?? 0,
                                               of: yesterday)
                        }
                    }
                    
                    return date
                }
            }
        }
        
        return nil
    }
}