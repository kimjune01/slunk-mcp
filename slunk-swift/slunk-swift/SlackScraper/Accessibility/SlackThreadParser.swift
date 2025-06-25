import Foundation
import ApplicationServices

// MARK: - Slack Thread Parser

/// Handles parsing thread conversations from Slack's accessibility tree
/// Based on reference SlackParser.swift:104-186
actor SlackThreadParser {
    
    // MARK: - State Machine
    
    /// Thread parsing state machine based on reference SlackParser.swift:111-114
    enum ThreadViewState {
        case searchingForHeader
        case processingMessages
    }
    
    // MARK: - Component Dependencies
    private let elementFinder = SlackElementFinder()
    private let messageParser = SlackMessageParser()
    
    // MARK: - Thread Parsing
    
    /// Parse thread view content and return SlackConversation
    /// Based on reference SlackParser.swift:104-186
    func parseThreadView(
        from viewContents: Element,
        workspace: String
    ) async throws -> SlackConversation? {
        
        // Find content list within thread view
        guard let contentList = try await elementFinder.findElementWithRole(
            from: viewContents,
            role: .list,
            subrole: .contentList
        ) else {
            print("❌ SlackThreadParser: No content list found in thread view")
            return nil
        }
        
        
        // Get all children for state machine processing
        guard let children = try contentList.getChildren() else {
            print("❌ SlackThreadParser: No children found in content list")
            return nil
        }
        
        
        // Initialize state machine variables
        var state: ThreadViewState = .searchingForHeader
        var channelName = ""
        var participants = ""
        var messages: [SlackMessage] = []
        
        // Process each child with state machine logic
        for (index, child) in children.enumerated() {
            guard let childElement = child as? Element else { continue }
            
            // Get DOM identifier for state transitions
            let domId = (try? childElement.getAttributeValue(.domIdentifier) as? String) ?? ""
            
            switch state {
            case .searchingForHeader:
                // Look for threads_view_heading (reference line 137)
                guard domId.starts(with: "threads_view_heading") else {
                    continue
                }
                
                
                // Extract channel name and participants from header children
                // Based on reference lines 141-144
                if let headerChildren = try childElement.getChildren(), headerChildren.count >= 2 {
                    if let firstChild = headerChildren[0] as? Element {
                        channelName = (try? firstChild.getValue()) ?? ""
                    }
                    
                    if let secondChild = headerChildren[1] as? Element {
                        participants = (try? secondChild.getValue()) ?? ""
                    }
                }
                
                // Transition to processing messages
                state = .processingMessages
                
            case .processingMessages:
                // Check for footer boundary (reference line 148)
                if domId.starts(with: "threads_view_footer") {
                    
                    // Create conversation from accumulated data
                    let conversation = try await createThreadConversation(
                        workspace: workspace,
                        channelName: channelName,
                        participants: participants,
                        messages: messages
                    )
                    
                    return conversation
                    
                } else {
                    // Process message element (reference line 165)
                    if let message = try await messageParser.parseMessageElement(childElement, index: index) {
                        messages.append(message)
                    }
                }
            }
        }
        
        // Handle case where we're still processing messages but reached end of children
        // Based on reference lines 172-183
        if state == .processingMessages && !messages.isEmpty {
            let conversation = try await createThreadConversation(
                workspace: workspace,
                channelName: channelName,
                participants: participants,
                messages: messages
            )
            
            return conversation
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Create thread conversation with proper channel naming
    /// Based on reference lines 149-151, 173-175
    private func createThreadConversation(
        workspace: String,
        channelName: String,
        participants: String,
        messages: [SlackMessage]
    ) async throws -> SlackConversation {
        
        // Build full channel name following reference pattern
        let fullChannelName = (workspace != "" ? workspace + ", " : "") +
            (channelName != "" ? channelName : "Thread") +
            (participants != "" ? " with " + participants : "")
        
        
        return SlackConversation(
            workspace: workspace.isEmpty ? "Unknown Workspace" : workspace,
            channel: fullChannelName,
            channelType: .publicChannel, // Threads inherit parent channel type (simplified)
            messages: messages
        )
    }
}