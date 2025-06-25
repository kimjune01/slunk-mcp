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
    
    // MARK: - Component Dependencies
    private let elementFinder = SlackElementFinder()
    private let messageParser = SlackMessageParser()
    private let workspaceParser = SlackWorkspaceParser()
    
    private init() {}
    
    // MARK: - Public Parsing Interface
    
    /// Parse Slack conversations from the application element
    public func parseCurrentConversation(
        from applicationElement: Element,
        timeout: TimeInterval = parseTimeout
    ) async throws -> SlackConversation? {
        
        print("🔍 SlackUIParser: Starting parseCurrentConversation using LBAccessibility")
        
        // Step 1: Find webArea element (Slack's main UI container)
        guard let webAreaElement = try await elementFinder.findWebAreaElement(from: applicationElement) else {
            print("❌ SlackUIParser: No webArea element found")
            return nil
        }
        
        print("✅ SlackUIParser: Found webArea element")
        
        // Debug: Check window title from application element
        if let appTitle = try applicationElement.getAttributeValue(.title) as? String {
            print("🔍 DEBUG: Application window title: '\(appTitle)'")
        }
        
        // Step 2: Find workspace wrapper using class matching
        guard let workspaceWrapper = try await elementFinder.findElementWithClass(
            from: webAreaElement,
            className: "p-client_workspace_wrapper"
        ) else {
            print("❌ SlackUIParser: No workspace wrapper found")
            return nil
        }
        
        print("✅ SlackUIParser: Found workspace wrapper")
        
        // Step 3: Extract workspace name
        // First try from the window title (most reliable)
        var workspace = try await workspaceParser.extractWorkspaceFromApplication(applicationElement)
        
        // If not found, try from workspace wrapper
        if workspace == nil {
            workspace = try await workspaceParser.extractWorkspaceName(from: workspaceWrapper)
        }
        
        // If still not found, look for workspace switcher element
        if workspace == nil {
            workspace = try await workspaceParser.extractWorkspaceFromSwitcher(webAreaElement)
        }
        
        let finalWorkspace = workspace ?? "Unknown Workspace"
        print("🔍 SlackUIParser: Workspace: \(finalWorkspace)")
        
        // Step 4: Find primary view contents
        guard let viewContents = try await elementFinder.findElementWithClass(
            from: workspaceWrapper,
            className: "p-view_contents--primary"
        ) else {
            print("❌ SlackUIParser: No primary view contents found")
            return nil
        }
        
        print("✅ SlackUIParser: Found primary view contents")
        
        // Step 5: Find content list with messages
        guard let contentList = try await elementFinder.findElementWithRole(
            from: viewContents,
            role: .list,
            subrole: .contentList
        ) else {
            print("❌ SlackUIParser: No content list found")
            return nil
        }
        
        print("✅ SlackUIParser: Found content list")
        
        // Step 6: Extract channel information
        let channel = try await workspaceParser.extractChannelName(from: contentList) ?? "Unknown Channel"
        print("🔍 SlackUIParser: Channel: \(channel)")
        
        // Step 7: Parse messages from content list
        let messages = try await messageParser.parseMessagesFromContentList(contentList)
        print("🔍 SlackUIParser: Parsed \(messages.count) messages")
        
        return SlackConversation(
            workspace: finalWorkspace,
            channel: channel,
            channelType: workspaceParser.determineChannelType(from: channel),
            messages: messages
        )
    }
    
    // MARK: - Helper Methods (kept for compatibility)
    
    /// Create debug summary using helpers
    private func createDebugSummary(
        workspace: String?,
        channel: String?,
        messages: [SlackMessage]
    ) -> String {
        return SlackParsingHelpers.createDebugSummary(
            workspace: workspace,
            channel: channel,
            messages: messages
        )
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