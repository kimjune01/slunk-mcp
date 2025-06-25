import Foundation
import ApplicationServices

// MARK: - Slack Workspace Parser

/// Handles parsing workspace and channel information from Slack's accessibility tree
actor SlackWorkspaceParser {
    
    // MARK: - Workspace Extraction
    
    /// Extract workspace name from element
    func extractWorkspaceName(from element: Element) async throws -> String? {
        print("🔍 SlackWorkspaceParser: Extracting workspace name...")
        
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
    
    /// Extract workspace name from application element window title
    func extractWorkspaceFromApplication(_ applicationElement: Element) async throws -> String? {
        // First try from the window title (most reliable)
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
                print("🔍 SlackWorkspaceParser: Window title: '\(windowTitle)'")
                return parseWorkspaceFromTitle(windowTitle)
            }
        }
        
        return nil
    }
    
    /// Find workspace switcher element and extract workspace name
    func extractWorkspaceFromSwitcher(_ webAreaElement: Element) async throws -> String? {
        print("🔍 SlackWorkspaceParser: Looking for workspace switcher...")
        let switcherMatcher = Matchers.hasClassContaining("p-workspace_switcher")
        
        if let switcher = try await webAreaElement.findElement(
            matching: switcherMatcher,
            maxDepth: 10,
            deadline: Deadline.fromNow(duration: 2.0)
        ) {
            let workspace = try switcher.getValue()
            print("   ✅ Found workspace from switcher: '\(workspace ?? "nil")'")
            return workspace
        }
        
        return nil
    }
    
    // MARK: - Channel Extraction
    
    /// Extract channel name from content list element
    func extractChannelName(from element: Element) async throws -> String? {
        print("🔍 SlackWorkspaceParser: Extracting channel name...")
        
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
    
    // MARK: - Thread View Detection
    
    /// Detect if current view is a thread view (based on reference SlackParser.swift:72-76)
    func detectThreadView(from viewContents: Element) async throws -> Bool {
        if let viewContentsDescription = try viewContents.getAttributeValue(.description) as? String {
            let isThreadView = viewContentsDescription == "Threads"
            if isThreadView {
                print("✅ THREAD VIEW DETECTED")
            }
            return isThreadView
        }
        
        return false
    }
    
    // MARK: - Channel Type Determination
    
    /// Determine channel type from channel name
    nonisolated func determineChannelType(from channelName: String) -> SlackConversation.ChannelType {
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
    
    // MARK: - Helper Methods
    
    /// Parse workspace name from title string
    private func parseWorkspaceFromTitle(_ title: String) -> String? {
        print("🔍 SlackWorkspaceParser: Parsing workspace from title: '\(title)'")
        
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
}