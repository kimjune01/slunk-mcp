import Foundation
import ApplicationServices

// MARK: - Slack Element Finder

/// Handles finding specific elements within Slack's accessibility tree
actor SlackElementFinder {
    
    // MARK: - Find Web Area
    
    /// Find webArea element using LBAccessibility matchers
    func findWebAreaElement(from applicationElement: Element) async throws -> Element? {
        debugPrint("🔍 SlackUIParser: Searching for webArea element...")
        
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
            debugPrint("❌ SlackUIParser: No window found")
            return nil
        }
        
        debugPrint("✅ SlackUIParser: Found window")
        
        // Now look for webArea within the window
        let webAreaMatcher = Matchers.hasRole(.webArea)
        
        let webArea = try await window.findElement(
            matching: webAreaMatcher,
            maxDepth: 15,
            deadline: Deadline.fromNow(duration: 5.0)
        ) as? Element
        
        if webArea == nil {
            debugPrint("❌ SlackUIParser: No webArea found in window")
            // Let's debug what we can find
            if let children = try window.getChildren() {
                debugPrint("🔍 Window has \(children.count) direct children")
                for (index, child) in children.prefix(5).enumerated() {
                    if let childElement = child as? Element,
                       let role = try? childElement.getAttributeValue(.role) as? Role {
                        debugPrint("  Child \(index): \(role.rawValue)")
                    }
                }
            }
        }
        
        return webArea
    }
    
    // MARK: - Find Elements by Class
    
    /// Find element with specific CSS class using LBAccessibility
    func findElementWithClass(
        from element: Element, 
        className: String
    ) async throws -> Element? {
        debugPrint("🔍 SlackUIParser: Searching for element with class: \(className)")
        
        // Use LBAccessibility class matcher
        let classMatcher = Matchers.hasClass(className)
        
        return try await element.findElement(
            matching: classMatcher,
            maxDepth: 15,
            deadline: Deadline.fromNow(duration: 5.0)
        ) as? Element
    }
    
    // MARK: - Find Elements by Role
    
    /// Find element with specific role and subrole
    func findElementWithRole(
        from element: Element,
        role: Role,
        subrole: Subrole? = nil
    ) async throws -> Element? {
        debugPrint("🔍 SlackUIParser: Searching for element with role: \(role)")
        
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
    
    /// Find all elements with specific role and subrole
    func findAllElementsWithRole(
        from element: Element,
        role: Role,
        subrole: Subrole? = nil
    ) async throws -> [Element] {
        var matchers: [ElementMatcher] = [Matchers.hasRole(role)]
        
        if let subrole = subrole {
            matchers.append(Matchers.hasAttribute(.subrole, equalTo: subrole))
        }
        
        let combinedMatcher = Matchers.all(matchers)
        
        // Use findElements (plural) to get all matching elements
        let foundElements = try await element.findElements(
            matching: combinedMatcher,
            maxDepth: 10,
            deadline: Deadline.fromNow(duration: 3.0)
        )
        
        return foundElements.compactMap { $0 as? Element }
    }
    
    // MARK: - Find Window
    
    /// Find the main Slack window
    func findMainWindow(from applicationElement: Element) async throws -> Element? {
        let windowMatcher = Matchers.all([
            Matchers.hasRole(.window),
            Matchers.hasAttribute(.subrole, equalTo: Subrole(rawValue: "AXStandardWindow"))
        ])
        
        return try await applicationElement.findElement(
            matching: windowMatcher,
            maxDepth: 2,
            deadline: Deadline.fromNow(duration: 1.0)
        ) as? Element
    }
    
    // MARK: - Thread DOM Identifier Matching
    
    /// Find element with DOM identifier starting with specified prefix
    /// Based on reference SlackParser.swift:133,137
    func findElementWithDOMIdentifierPrefix(
        from element: Element,
        prefix: String
    ) async throws -> Element? {
        
        // Get all children to check their DOM identifiers
        guard let children = try element.getChildren() else {
            return nil
        }
        
        for child in children {
            if let childElement = child as? Element {
                if let domId = try? childElement.getAttributeValue(.domIdentifier) as? String {
                    if domId.starts(with: prefix) {
                        return childElement
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Find thread view header element
    /// Based on reference SlackParser.swift:137 - domId.starts(with: "threads_view_heading")
    func findThreadViewHeader(from contentList: Element) async throws -> Element? {
        return try await findElementWithDOMIdentifierPrefix(
            from: contentList,
            prefix: "threads_view_heading"
        )
    }
    
    /// Find thread view footer element  
    /// Based on reference SlackParser.swift:148 - domId.starts(with: "threads_view_footer")
    func findThreadViewFooter(from contentList: Element) async throws -> Element? {
        return try await findElementWithDOMIdentifierPrefix(
            from: contentList,
            prefix: "threads_view_footer"
        )
    }
}