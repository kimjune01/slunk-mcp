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
        let workspace = try await extractWorkspaceName(from: workspaceWrapper) ?? "Unknown Workspace"
        print("🔍 SlackUIParser: Workspace: \(workspace)")
        
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
            workspace: workspace,
            channel: channel,
            channelType: determineChannelType(from: channel),
            messages: messages
        )
    }
    
    // MARK: - Private Element Finding Methods
    
    /// Find webArea element using LBAccessibility matchers
    private func findWebAreaElement(from applicationElement: Element) async throws -> Element? {
        print("🔍 SlackUIParser: Searching for webArea element...")
        
        // Use LBAccessibility matcher for webArea role
        let webAreaMatcher = Matchers.hasRole(.webArea)
        
        return try await applicationElement.findElement(
            matching: webAreaMatcher,
            maxDepth: 10,
            deadline: Deadline.fromNow(duration: 5.0)
        ) as? Element
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
        // Try to get workspace from window title or element attributes
        if let title = try element.getAttributeValue(.title) as? String {
            return parseWorkspaceFromTitle(title)
        }
        
        // Try description attribute
        if let description = try element.getAttributeValue(.description) as? String {
            return parseWorkspaceFromTitle(description)
        }
        
        return nil
    }
    
    /// Extract channel name from content list element
    private func extractChannelName(from element: Element) async throws -> String? {
        // Try to get channel name from element description or title
        if let description = try element.getAttributeValue(.description) as? String,
           !description.isEmpty {
            return description
        }
        
        if let title = try element.getAttributeValue(.title) as? String,
           !title.isEmpty {
            return title
        }
        
        // Try to find a channel header element within the list
        let channelHeaderMatcher = Matchers.hasClassContaining("channel")
        
        if let headerElement = try await element.findElement(
            matching: channelHeaderMatcher,
            maxDepth: 5,
            deadline: Deadline.fromNow(duration: 2.0)
        ) {
            return try headerElement.getValue()
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
        
        // Extract sender and timestamp from main children
        for child in mainChildren {
            if let childElement = child as? Element,
               let role = try childElement.getAttributeValue(.role) as? Role {
                if role == .button {
                    // Sender name is often in a button element
                    sender = try childElement.getAttributeValue(.title) as? String
                } else if role == .link {
                    // Timestamp is often in a link element
                    if let description = try childElement.getAttributeValue(.description) as? String,
                       description.contains("at ") {
                        timestamp = parseSlackTimestamp(from: description)
                    }
                }
            }
        }
        
        // Extract message content using tree traversal
        let content = try await extractMessageContent(from: mainGroup)
        
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
        // Pattern: "Something - WorkspaceName - Slack"
        guard let endRange = title.range(of: " - Slack", options: .backwards) else {
            return nil
        }
        
        let beforeSlack = title[..<endRange.lowerBound]
        
        guard let lastDashRange = beforeSlack.range(of: " - ", options: .backwards) else {
            return String(beforeSlack)
        }
        
        let workspaceStart = lastDashRange.upperBound
        return String(title[workspaceStart..<endRange.lowerBound])
    }
    
    /// Parse Slack timestamp from description string
    private func parseSlackTimestamp(from description: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        // Extract time from description like "at 2:30 PM"
        if let timeRange = description.range(of: "at ") {
            let timeString = String(description[timeRange.upperBound...])
            return formatter.date(from: timeString)
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
        
        do {
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
            
        } catch {
            print("❌ SlackUIParser: Error dumping element tree: \(error)")
        }
    }
}