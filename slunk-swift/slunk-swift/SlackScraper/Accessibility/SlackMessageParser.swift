import Foundation
import ApplicationServices

// MARK: - Slack Message Parser

/// Handles parsing individual messages from Slack's accessibility tree
actor SlackMessageParser {
    
    // MARK: - Message Parsing
    
    /// Parse messages from content list using LBAccessibility
    func parseMessagesFromContentList(_ contentList: Element) async throws -> [SlackMessage] {
        // Check if this is a thread sidebar for processing context
        let _ = (try? contentList.getAttributeValue(.description) as? String)?.contains("Thread") ?? false
        
        // Get all child elements that might be messages
        guard let children = try contentList.getChildren() else {
            print("❌ SlackMessageParser: No children found in content list")
            return []
        }
        
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
                        }
                    } else if role == .staticText && sender == nil {
                        // Sometimes sender is just static text
                        if let text = try childElement.getValue(), !text.isEmpty {
                            // Check if this looks like a username
                            if !text.contains(":") && text.count < 50 {
                                sender = text
                            }
                        }
                    }
                }
            }
        }
        
        // If still no sender, look deeper in the tree
        if sender == nil {
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
                // Sender found via deep search
            }
        }
        
        // Extract message content with thread detection using tree traversal
        let contentResult = try await extractMessageContentWithThreads(from: mainGroup)
        let content = contentResult.content
        
        // If we have content but no sender, use a placeholder
        if let content = content, !content.isEmpty, sender == nil {
            sender = "Unknown User"
        }
        
        guard let content = content, !content.isEmpty,
              let sender = sender else {
            return nil
        }
        
        // Extract additional metadata
        let mentions = SlackParsingHelpers.extractMentions(from: content)
        let reactions = try await extractReactions(from: mainGroup)
        let attachmentNames = try await extractAttachmentNames(from: mainGroup)
        let threadId = contentResult.threadId
        
        // Create content hash for deduplication
        let contentHash = SlackMessage.generateContentHash(
            content: content,
            sender: sender,
            timestamp: timestamp ?? Date()
        )
        
        // Create metadata
        let metadata = SlackMessage.MessageMetadata(
            reactions: reactions.isEmpty ? nil : reactions,
            mentions: mentions.isEmpty ? nil : mentions,
            attachmentNames: attachmentNames.isEmpty ? nil : attachmentNames,
            contentHash: contentHash
        )
        
        let finalMessage = SlackMessage(
            timestamp: timestamp ?? Date(),
            sender: sender,
            content: content,
            threadId: threadId,
            messageType: contentResult.isThread ? .thread : .regular,
            metadata: metadata
        )
        
        // Log successful message extraction
        print("✅ Extracted message from \(finalMessage.sender)")
        
        return finalMessage
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
        let threadId: String?
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
        
        // Generate thread ID if this is a thread message
        let threadId = !threadInfo.isEmpty ? "thread_\(Date().timeIntervalSince1970)" : nil
        
        return ContentResult(
            content: finalContent.isEmpty ? nil : finalContent,
            isThread: !threadInfo.isEmpty,
            threadInfo: threadInfo,
            threadId: threadId
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
    
    // MARK: - Enhanced Extraction Methods
    
    /// Extract emoji reactions from message element
    func extractReactions(from element: Element) async throws -> [String: Int] {
        var reactions: [String: Int] = [:]
        
        // Look for reaction elements in the message
        let reactionMatcher = Matchers.any([
            Matchers.hasClassContaining("reaction"),
            Matchers.hasClassContaining("emoji"),
            Matchers.all([
                Matchers.hasRole(.button),
                Matchers.hasAttribute(.description, substring: "reaction")
            ])
        ])
        
        do {
            let reactionElements = try await element.findElements(
                matching: reactionMatcher,
                maxDepth: 8,
                deadline: Deadline.fromNow(duration: 2.0)
            )
            
            for reactionElement in reactionElements {
                if let reactionData = try await parseReactionElement(reactionElement as! Element) {
                    reactions[reactionData.emoji] = reactionData.count
                }
            }
        } catch {
            print("⚠️ Failed to extract reactions: \(error)")
        }
        
        return reactions
    }
    
    /// Parse individual reaction element
    private func parseReactionElement(_ element: Element) async throws -> (emoji: String, count: Int)? {
        // Try to get reaction info from title, value, or description
        let title = element.getSafeTitle() ?? ""
        let value = element.getSafeStringValue() ?? ""
        let description = element.getSafeDescription() ?? ""
        
        let combinedText = "\(title) \(value) \(description)"
        
        // Updated patterns for Slack's actual format
        let patterns = [
            // Pattern 1: "2 reactions, react with excited emoji" -> excited = 2
            #"(\d+)\s+reactions?,\s+react\s+with\s+(\w+)\s+emoji"#,
            
            // Pattern 2: "excited emoji" (assume count = 1 if no number found)
            #"^(\w+)\s+emoji$"#,
            
            // Pattern 3: Direct emoji with count "👍 3"
            #"([\p{Emoji_Presentation}\p{Emoji}\uFE0F])\s*(\d+)"#,
            
            // Pattern 4: "thumbs up, 2 reactions" 
            #"(\w+)\s*(?:up|down|hand|face|heart)?\s*,\s*(\d+)\s*reactions?"#,
            
            // Pattern 5: Just the emoji name with assumed count 1
            #"^(\w+)$"#
        ]
        
        for (index, pattern) in patterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: combinedText, range: NSRange(combinedText.startIndex..., in: combinedText)) {
                
                if index == 0 {
                    // Pattern 1: count first, then emoji name
                    if let countRange = Range(match.range(at: 1), in: combinedText),
                       let emojiRange = Range(match.range(at: 2), in: combinedText),
                       let count = Int(String(combinedText[countRange])) {
                        let emoji = String(combinedText[emojiRange])
                        return (emoji: emoji, count: count)
                    }
                } else if index == 1 || index == 4 {
                    // Pattern 2 & 5: emoji name only, assume count = 1
                    if let emojiRange = Range(match.range(at: 1), in: combinedText) {
                        let emoji = String(combinedText[emojiRange])
                        return (emoji: emoji, count: 1)
                    }
                } else if index == 2 {
                    // Pattern 3: emoji first, then count
                    if let emojiRange = Range(match.range(at: 1), in: combinedText),
                       let countRange = Range(match.range(at: 2), in: combinedText),
                       let count = Int(String(combinedText[countRange])) {
                        let emoji = String(combinedText[emojiRange])
                        return (emoji: emoji, count: count)
                    }
                } else if index == 3 {
                    // Pattern 4: emoji name first, then count
                    if let emojiRange = Range(match.range(at: 1), in: combinedText),
                       let countRange = Range(match.range(at: 2), in: combinedText),
                       let count = Int(String(combinedText[countRange])) {
                        let emoji = String(combinedText[emojiRange])
                        return (emoji: emoji, count: count)
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Extract attachment file names from message element
    func extractAttachmentNames(from element: Element) async throws -> [String] {
        var attachmentNames: [String] = []
        
        // Look for attachment elements
        let attachmentMatcher = Matchers.any([
            Matchers.hasClassContaining("attachment"),
            Matchers.hasClassContaining("file"),
            Matchers.hasClassContaining("upload"),
            Matchers.hasAttribute(.description, substring: "uploaded"),
            Matchers.hasAttribute(.description, substring: "file"),
            Matchers.hasAttribute(.title, substring: ".pdf"),
            Matchers.hasAttribute(.title, substring: ".jpg"),
            Matchers.hasAttribute(.title, substring: ".png"),
            Matchers.hasAttribute(.title, substring: ".doc")
        ])
        
        do {
            let attachmentElements = try await element.findElements(
                matching: attachmentMatcher,
                maxDepth: 8,
                deadline: Deadline.fromNow(duration: 2.0)
            )
            
            for attachmentElement in attachmentElements {
                if let fileName = try await parseAttachmentElement(attachmentElement as! Element) {
                    attachmentNames.append(fileName)
                }
            }
        } catch {
            print("⚠️ Failed to extract attachments: \(error)")
        }
        
        // Also look for file patterns in the text content
        let content = try await extractMessageContent(from: element) ?? ""
        let filePatterns = extractFileNamesFromText(content)
        attachmentNames.append(contentsOf: filePatterns)
        
        let finalAttachments = Array(Set(attachmentNames)) // Remove duplicates
        return finalAttachments
    }
    
    /// Parse individual attachment element
    private func parseAttachmentElement(_ element: Element) async throws -> String? {
        let title = element.getSafeTitle() ?? ""
        let value = element.getSafeStringValue() ?? ""
        let description = element.getSafeDescription() ?? ""
        
        let combinedText = "\(title) \(value) \(description)"
        
        // Enhanced patterns for Slack's attachment formats
        let patterns = [
            // Pattern 1: Traditional file attachments
            #"([\w\-\.]+\.[a-zA-Z]{2,5})"#,  // filename.ext
            #"uploaded\s+([\w\-\.]+)"#,        // uploaded filename
            #"file\s+([\w\-\.]+)"#,           // file filename
            
            // Pattern 2: URL/Link patterns (from logs: "in.linkedin.com")
            #"([a-zA-Z0-9\-]+\.[a-zA-Z]{2,10}(?:\.[a-zA-Z]{2,5})?)"#,  // domain.com or subdomain.domain.com
            
            // Pattern 3: Link title extraction (from logs: "Rohan Bhagwat - Boomerang | LinkedIn")
            #"^([^|]+)\s*\|\s*LinkedIn"#,        // "Name - Title | LinkedIn"
            #"^([^(]+)\s*\(opens in new tab\)"#, // "Title (opens in new tab)"
            
            // Pattern 4: Clean link text patterns
            #"^([A-Za-z0-9\s\-]+)(?:\s*-\s*[A-Za-z\s]+)?$"#  // Clean readable titles
        ]
        
        for (index, pattern) in patterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: combinedText, range: NSRange(combinedText.startIndex..., in: combinedText))
                for match in matches {
                    if let fileRange = Range(match.range(at: 1), in: combinedText) {
                        let fileName = String(combinedText[fileRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if isValidAttachmentName(fileName) {
                            return fileName
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Extract file names from text content using pattern matching
    private func extractFileNamesFromText(_ text: String) -> [String] {
        let filePattern = #"([\w\-\.]+\.(pdf|doc|docx|xls|xlsx|ppt|pptx|jpg|jpeg|png|gif|zip|txt|csv))"#
        
        guard let regex = try? NSRegularExpression(pattern: filePattern, options: [.caseInsensitive]) else {
            return []
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var fileNames: [String] = []
        
        for match in matches {
            if let fileRange = Range(match.range(at: 1), in: text) {
                fileNames.append(String(text[fileRange]))
            }
        }
        
        return fileNames
    }
    
    /// Validate if a string looks like a valid file name
    private func isValidFileName(_ fileName: String) -> Bool {
        // Check if it has a reasonable extension
        let validExtensions = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", 
                               "jpg", "jpeg", "png", "gif", "zip", "txt", "csv", "mp4", "mov"]
        
        let lowercased = fileName.lowercased()
        let hasValidExtension = validExtensions.contains { lowercased.hasSuffix($0) }
        
        // Check reasonable length and no suspicious patterns
        return hasValidExtension && 
               fileName.count > 3 && 
               fileName.count < 100 &&
               !fileName.contains("\n") &&
               !fileName.contains("  ")
    }
    
    /// Validate if a string looks like a valid attachment name (including URLs and links)
    private func isValidAttachmentName(_ name: String) -> Bool {
        // Skip empty, very short, or very long names
        guard name.count >= 3 && name.count <= 200 && !name.contains("\n") else {
            return false
        }
        
        // Valid file extensions
        let validExtensions = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", 
                               "jpg", "jpeg", "png", "gif", "zip", "txt", "csv", "mp4", "mov"]
        
        let lowercased = name.lowercased()
        
        // Check 1: Traditional file with extension
        if validExtensions.contains(where: { lowercased.hasSuffix($0) }) {
            return true
        }
        
        // Check 2: Domain/URL patterns
        if name.contains(".com") || name.contains(".org") || name.contains(".net") || 
           name.contains(".io") || name.contains(".ai") || name.contains(".co") {
            return true
        }
        
        // Check 3: Meaningful link titles (exclude generic text)
        let exclusions = ["reactions", "add reaction", "reply", "thread", "edited", "delete", "more actions"]
        if exclusions.contains(where: { lowercased.contains($0) }) {
            return false
        }
        
        // Check 4: Has meaningful content (contains letters and reasonable length)
        let hasLetters = name.rangeOfCharacter(from: .letters) != nil
        let hasReasonableLength = name.count >= 5
        
        return hasLetters && hasReasonableLength
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