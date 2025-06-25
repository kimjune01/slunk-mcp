import Foundation
import ApplicationServices

// MARK: - Slack UI Parser using LBAccessibility Framework

/// Main parser for extracting Slack content from accessibility elements using the LBAccessibility framework
public actor SlackUIParser {
    public static let shared = SlackUIParser()
    
    // MARK: - Configuration
    public static let parseTimeout: TimeInterval = 30.0
    private static let maxElementsPerParse = 500
    private static let retryAttempts = 2
    
    private init() {}
    
    // MARK: - Public Parsing Interface
    
    /// Parse Slack conversations from the application element
    public func parseCurrentConversation(
        from applicationElement: Element,
        timeout: TimeInterval = parseTimeout
    ) async throws -> SlackConversation? {
        
        print("🔍 SlackUIParser: Starting parseCurrentConversation using LBAccessibility")
        
        // Step 1: Find webArea element (Slack's main UI container)
        guard let webAreaElement = try await findWebAreaElement(from: applicationElement) else {
            print("❌ SlackUIParser: No webArea element found")
            return nil
        }
        
        print("✅ SlackUIParser: Found webArea element")
        
        // Debug: Check window title from application element
        if let appTitle = try applicationElement.getAttributeValue(.title) as? String {
            print("🔍 DEBUG: Application window title: '\(appTitle)'")
        }
        
        // Step 2: Find workspace wrapper using class matching
        guard let workspaceWrapper = try await findElementWithClass(
            from: webAreaElement,
            className: "p-client_workspace_wrapper"
        ) else {
            print("❌ SlackUIParser: No workspace wrapper found")
            return nil
        }
        
        print("✅ SlackUIParser: Found workspace wrapper")
        
        // Step 3: Extract workspace name
        // First try from the window title (most reliable)
        var workspace: String? = nil
        
        // Get window title directly
        let windowMatcher = Matchers.all([
            Matchers.hasRole(.window),
            Matchers.hasAttribute(.subrole, equalTo: Subrole(rawValue: "AXStandardWindow"))
        ])
        
        if let window = try await applicationElement.findElement(
            matching: windowMatcher,
            maxDepth: 2,
            deadline: Deadline.fromNow(duration: 1.0)
        ) as? Element {
            if let windowTitle = try window.getAttributeValue(.title) as? String {
                print("🔍 DEBUG: Window title: '\(windowTitle)'")
                workspace = parseWorkspaceFromTitle(windowTitle)
            }
        }
        
        // If not found, try from workspace wrapper
        if workspace == nil {
            workspace = try await extractWorkspaceName(from: workspaceWrapper)
        }
        
        // If still not found, look for workspace switcher element
        if workspace == nil {
            print("🔍 DEBUG: Looking for workspace switcher...")
            let switcherMatcher = Matchers.hasClassContaining("p-workspace_switcher")
            if let switcher = try await webAreaElement.findElement(
                matching: switcherMatcher,
                maxDepth: 10,
                deadline: Deadline.fromNow(duration: 2.0)
            ) {
                workspace = try switcher.getValue()
                print("   ✅ Found workspace from switcher: '\(workspace ?? "nil")'")
            }
        }
        
        let finalWorkspace = workspace ?? "Unknown Workspace"
        print("🔍 SlackUIParser: Workspace: \(finalWorkspace)")
        
        // Step 4: Find primary view contents
        guard let viewContents = try await findElementWithClass(
            from: workspaceWrapper,
            className: "p-view_contents--primary"
        ) else {
            print("❌ SlackUIParser: No primary view contents found")
            return nil
        }
        
        print("✅ SlackUIParser: Found primary view contents")
        
        // Step 5: Find content list with messages
        guard let contentList = try await findElementWithRole(
            from: viewContents,
            role: .list,
            subrole: .contentList
        ) else {
            print("❌ SlackUIParser: No content list found")
            return nil
        }
        
        print("✅ SlackUIParser: Found content list")
        
        // Step 6: Extract channel information
        let channel = try await extractChannelName(from: contentList) ?? "Unknown Channel"
        print("🔍 SlackUIParser: Channel: \(channel)")
        
        // Step 7: Parse messages from content list
        let messages = try await parseMessagesFromContentList(contentList)
        print("🔍 SlackUIParser: Parsed \(messages.count) messages")
        
        return SlackConversation(
            workspace: finalWorkspace,
            channel: channel,
            channelType: determineChannelType(from: channel),
            messages: messages
        )
    }
    
    // MARK: - Private Element Finding Methods
    
    /// Find webArea element using LBAccessibility matchers
    private func findWebAreaElement(from applicationElement: Element) async throws -> Element? {
        print("🔍 SlackUIParser: Searching for webArea element...")
        
        // First, let's find the main window
        let windowMatcher = Matchers.all([
            Matchers.hasRole(.window),
            Matchers.hasAttribute(.subrole, equalTo: Subrole(rawValue: "AXStandardWindow"))
        ])
        
        guard let window = try await applicationElement.findElement(
            matching: windowMatcher,
            maxDepth: 2,
            deadline: Deadline.fromNow(duration: 2.0)
        ) as? Element else {
            print("❌ SlackUIParser: No window found")
            return nil
        }
        
        print("✅ SlackUIParser: Found window")
        
        // Now look for webArea within the window
        let webAreaMatcher = Matchers.hasRole(.webArea)
        
        let webArea = try await window.findElement(
            matching: webAreaMatcher,
            maxDepth: 15,
            deadline: Deadline.fromNow(duration: 5.0)
        ) as? Element
        
        if webArea == nil {
            print("❌ SlackUIParser: No webArea found in window")
            // Let's debug what we can find
            if let children = try window.getChildren() {
                print("🔍 Window has \(children.count) direct children")
                for (index, child) in children.prefix(5).enumerated() {
                    if let childElement = child as? Element,
                       let role = try? childElement.getAttributeValue(.role) as? Role {
                        print("  Child \(index): \(role.rawValue)")
                    }
                }
            }
        }
        
        return webArea
    }
    
    /// Find element with specific CSS class using LBAccessibility
    private func findElementWithClass(
        from element: Element, 
        className: String
    ) async throws -> Element? {
        print("🔍 SlackUIParser: Searching for element with class: \(className)")
        
        // Use LBAccessibility class matcher
        let classMatcher = Matchers.hasClass(className)
        
        return try await element.findElement(
            matching: classMatcher,
            maxDepth: 15,
            deadline: Deadline.fromNow(duration: 5.0)
        ) as? Element
    }
    
    /// Find element with specific role and subrole
    private func findElementWithRole(
        from element: Element,
        role: Role,
        subrole: Subrole? = nil
    ) async throws -> Element? {
        print("🔍 SlackUIParser: Searching for element with role: \(role)")
        
        var matchers: [ElementMatcher] = [Matchers.hasRole(role)]
        
        if let subrole = subrole {
            matchers.append(Matchers.hasAttribute(.subrole, equalTo: subrole))
        }
        
        let combinedMatcher = Matchers.all(matchers)
        
        return try await element.findElement(
            matching: combinedMatcher,
            maxDepth: 10,
            deadline: Deadline.fromNow(duration: 3.0)
        ) as? Element
    }
    
    // MARK: - Private Content Extraction Methods
    
    /// Extract workspace name from element
    private func extractWorkspaceName(from element: Element) async throws -> String? {
        print("🔍 DEBUG: Extracting workspace name...")
        
        // Debug: Print all available attributes
        let attributes: [Attribute] = [.title, .description, .value, .help]
        for attr in attributes {
            if let value = try? element.getAttributeValue(attr) as? String {
                print("   📊 \(attr): '\(value)'")
            }
        }
        
        // Try to get workspace from window title or element attributes
        if let title = try element.getAttributeValue(.title) as? String {
            print("   🔍 Found title: '\(title)'")
            let parsed = parseWorkspaceFromTitle(title)
            print("   🔍 Parsed workspace: '\(parsed ?? "nil")'")
            return parsed
        }
        
        // Try description attribute
        if let description = try element.getAttributeValue(.description) as? String {
            print("   🔍 Found description: '\(description)'")
            return parseWorkspaceFromTitle(description)
        }
        
        // Try to find workspace info in children
        if let children = try element.getChildren() {
            print("   🔍 Checking \(children.count) children for workspace info...")
            for (index, child) in children.prefix(5).enumerated() {
                if let childElement = child as? Element {
                    if let value = try? childElement.getValue() {
                        print("   📊 Child \(index) value: '\(value)'")
                    }
                    if let title = try? childElement.getAttributeValue(.title) as? String {
                        print("   📊 Child \(index) title: '\(title)'")
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Extract channel name from content list element
    private func extractChannelName(from element: Element) async throws -> String? {
        print("🔍 DEBUG: Extracting channel name...")
        
        // Debug: Print element attributes
        if let description = try element.getAttributeValue(.description) as? String {
            print("   📊 Content list description: '\(description)'")
            if !description.isEmpty {
                return description
            }
        }
        
        if let title = try element.getAttributeValue(.title) as? String {
            print("   📊 Content list title: '\(title)'")
            if !title.isEmpty {
                return title
            }
        }
        
        // Try to find channel info in various ways
        print("   🔍 Looking for channel header elements...")
        
        // Look for elements with channel-related classes
        let channelMatchers = [
            Matchers.hasClassContaining("channel"),
            Matchers.hasClassContaining("p-channel"),
            Matchers.hasClassContaining("header"),
            Matchers.hasClassContaining("title")
        ]
        
        for (index, matcher) in channelMatchers.enumerated() {
            if let headerElement = try await element.findElement(
                matching: matcher,
                maxDepth: 5,
                deadline: Deadline.fromNow(duration: 2.0)
            ) {
                if let value = try headerElement.getValue() {
                    print("   ✅ Found channel via matcher \(index): '\(value)'")
                    return value
                }
            }
        }
        
        // Try to find any text in the first few children
        if let children = try element.getChildren() {
            print("   🔍 Checking first children for channel info...")
            for (index, child) in children.prefix(10).enumerated() {
                if let childElement = child as? Element {
                    if let value = try? childElement.getValue(), !value.isEmpty {
                        print("   📊 Child \(index) text: '\(value)'")
                        // Look for channel patterns
                        if value.hasPrefix("#") || value.hasPrefix("@") {
                            print("   ✅ Found channel name: '\(value)'")
                            return value
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Parse messages from content list using LBAccessibility
    private func parseMessagesFromContentList(_ contentList: Element) async throws -> [SlackMessage] {
        print("🔍 SlackUIParser: Parsing messages from content list...")
        
        // Get all child elements that might be messages
        guard let children = try contentList.getChildren() else {
            print("❌ SlackUIParser: No children found in content list")
            return []
        }
        
        print("🔍 SlackUIParser: Found \(children.count) child elements")
        
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
    private func parseMessageElement(_ element: Element, index: Int) async throws -> SlackMessage? {
        print("🔍 SlackUIParser: Parsing message element \(index)")
        
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
    private func extractMessageFromGroup(_ messageGroup: Element, index: Int) async throws -> SlackMessage? {
        print("🔍 SlackUIParser: Extracting message from group \(index)")
        
        guard let groupChildren = try messageGroup.getChildren(),
              let mainGroup = groupChildren.first as? Element else {
            return nil
        }
        
        guard let mainChildren = try mainGroup.getChildren() else {
            return nil
        }
        
        var sender: String?
        var timestamp: Date?
        
        print("   🔍 Looking for sender in \(mainChildren.count) children...")
        
        // Extract sender and timestamp from main children
        for (childIndex, child) in mainChildren.enumerated() {
            if let childElement = child as? Element {
                // Debug: print all attributes of each child
                if let role = try? childElement.getAttributeValue(.role) as? Role {
                    print("   📊 Child \(childIndex) role: \(role.rawValue)")
                    
                    // Try multiple attributes for sender name
                    if let title = try? childElement.getAttributeValue(.title) as? String {
                        print("     - title: '\(title)'")
                    }
                    if let value = try? childElement.getValue() {
                        print("     - value: '\(value)'")
                    }
                    if let desc = try? childElement.getAttributeValue(.description) as? String {
                        print("     - description: '\(desc)'")
                    }
                    
                    if role == .button && sender == nil {
                        // Sender name is often in a button element
                        let buttonTitle = try childElement.getAttributeValue(.title) as? String
                        let buttonValue = try childElement.getValue()
                        let potentialSender = buttonTitle ?? buttonValue
                        
                        // Filter out buttons that are clearly not senders
                        if let s = potentialSender, 
                           !s.contains("replies") && 
                           !s.contains("reaction") && 
                           !s.contains("thread") &&
                           !s.contains("edited") &&
                           !s.isEmpty {
                            sender = s
                            print("   ✅ Found sender from button: '\(s)'")
                        }
                    } else if role == .link {
                        // Could be sender or timestamp
                        let linkText = try childElement.getValue() ?? ""
                        let linkDesc = try childElement.getAttributeValue(.description) as? String ?? ""
                        
                        print("     - link text: '\(linkText)'")
                        print("     - link desc: '\(linkDesc)'")
                        
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
        
        // Extract message content using tree traversal
        let content = try await extractMessageContent(from: mainGroup)
        
        // If we have content but no sender, use a placeholder
        if let content = content, !content.isEmpty, sender == nil {
            sender = "Unknown User"
            print("   ⚠️ Using placeholder sender for message with content")
        }
        
        guard let content = content, !content.isEmpty,
              let sender = sender else {
            print("❌ SlackUIParser: Missing required message data (content: \(content?.isEmpty ?? true), sender: \(sender == nil))")
            return nil
        }
        
        print("✅ SlackUIParser: Extracted message from \(sender): \(String(content.prefix(50)))")
        
        return SlackMessage(
            timestamp: timestamp ?? Date(),
            sender: sender,
            content: content,
            messageType: .regular
        )
    }
    
    /// Extract text content from element using LBAccessibility tree traversal
    private func extractMessageContent(from element: Element) async throws -> String? {
        // Use LBAccessibility tree value collection
        let content = try await element.collectTreeValues(
            matching: Matchers.hasRole(.staticText),
            maxDepth: 10,
            separator: " "
        )
        
        return content?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Helper Methods
    
    /// Parse workspace name from title string
    private func parseWorkspaceFromTitle(_ title: String) -> String? {
        print("🔍 DEBUG: Parsing workspace from title: '\(title)'")
        
        // Common patterns:
        // 1. "js-help (Channel) - LangChain Community - Slack" (your current format)
        // 2. "Channel - Workspace - Slack"
        // 3. "Workspace - Slack"
        // 4. "Slack | Workspace | #channel"
        
        // Pattern 1: Try "Something - WorkspaceName - Slack"
        if let endRange = title.range(of: " - Slack", options: .backwards) {
            let beforeSlack = title[..<endRange.lowerBound]
            
            if let lastDashRange = beforeSlack.range(of: " - ", options: .backwards) {
                let workspaceStart = lastDashRange.upperBound
                let workspace = String(title[workspaceStart..<endRange.lowerBound])
                print("   ✅ Parsed workspace (pattern 1): '\(workspace)'")
                return workspace
            } else {
                // Only one part before " - Slack"
                let workspace = String(beforeSlack)
                print("   ✅ Parsed workspace (pattern 1b): '\(workspace)'")
                return workspace
            }
        }
        
        // Pattern 2: Try "Slack | Workspace | ..."
        if title.hasPrefix("Slack") && title.contains(" | ") {
            let parts = title.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 {
                let workspace = parts[1]
                print("   ✅ Parsed workspace (pattern 2): '\(workspace)'")
                return workspace
            }
        }
        
        print("   ❌ Could not parse workspace from title")
        return nil
    }
    
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
    
    /// Determine channel type from channel name
    private func determineChannelType(from channelName: String) -> SlackConversation.ChannelType {
        if channelName.hasPrefix("#") {
            return .publicChannel
        } else if channelName.hasPrefix("@") {
            return .directMessage
        } else if channelName.lowercased().contains("private") {
            return .privateChannel
        } else {
            return .publicChannel
        }
    }
}

// MARK: - Debug Extension

public extension SlackUIParser {
    /// Debug method to print element tree using LBAccessibility
    func debugElementTree(from element: Element, maxDepth: Int = 5) async {
        print("🌳 SlackUIParser: Printing element tree with LBAccessibility...")
        
        // Create a simple debug output instead of dumpSendable
        let role = try? element.getAttributeValue(.role) as? Role
        let title = try? element.getAttributeValue(.title) as? String
        let description = try? element.getAttributeValue(.description) as? String
        let children = try? element.getChildren()
        
        print("Element:")
        print("  Role: \(role?.rawValue ?? "nil")")
        print("  Title: \(title ?? "nil")")
        print("  Description: \(description ?? "nil")")
        print("  Children: \(children?.count ?? 0)")
    }
}