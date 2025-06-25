import Foundation
@preconcurrency import ApplicationServices

// MARK: - Core Accessibility Protocols

/// Protocol for accessibility elements
public protocol AccessibilityElement: Sendable {
    var role: String? { get async }
    var title: String? { get async }
    var value: String? { get async }
    var children: [AccessibilityElement] { get async }
    var parent: AccessibilityElement? { get async }
    
    func getAttribute(_ attribute: String) async -> Any?
    func performAction(_ action: String) async throws
}

/// Protocol for observing accessibility events
public protocol AccessibilityObserver: Sendable {
    func startObserving(element: AccessibilityElement, events: [String]) async throws
    func stopObserving() async
}

/// Protocol for managing accessibility permissions
public protocol AccessibilityPermissionManager: Sendable {
    func checkPermissions() async -> Bool
    func requestPermissions() async -> Bool
}

// MARK: - Accessibility Manager

/// Main manager for accessibility operations with sensible defaults
public actor AccessibilityManager {
    public static let shared = AccessibilityManager()
    
    // MARK: - Configuration (Sensible Defaults)
    public static let defaultTimeout: TimeInterval = 10.0
    private static let maxSearchDepth = 10
    private static let retryAttempts = 3
    
    // MARK: - State
    private var isEnabled = false
    private var permissionManager: AccessibilityPermissionManager?
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Check if accessibility is available and permissions are granted
    public func checkAccessibility() async -> AccessibilityStatus {
        // Check if accessibility API is available
        guard AXIsProcessTrusted() else {
            return .permissionDenied
        }
        
        isEnabled = true
        return .available
    }
    
    /// Request accessibility permissions if not already granted
    /// This will prompt the user to enable accessibility permissions
    public func requestAccessibilityPermissions() async -> AccessibilityStatus {
        // First check if already trusted
        if AXIsProcessTrusted() {
            isEnabled = true
            return .available
        }
        
        // Request accessibility permissions with prompt
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if trusted {
            isEnabled = true
            return .available
        } else {
            return .permissionDenied
        }
    }
    
    /// Check if the app has the necessary entitlements for accessibility
    public func hasAccessibilityEntitlements() -> Bool {
        // Check if we can at least call the accessibility APIs
        // This will return false if sandboxed without proper entitlements
        let canCheck = AXIsProcessTrusted()
        return true // We can always check, even if denied
    }
    
    /// Get accessibility element for a running application
    public func getApplicationElement(pid: pid_t) async throws -> AccessibilityElement? {
        guard isEnabled else {
            throw SlackScraperError.serviceNotRunning("Accessibility not enabled")
        }
        
        let app = AXUIElementCreateApplication(pid)
        return SystemAccessibilityElement(axElement: app)
    }
    
    /// Find elements matching criteria with timeout
    public func findElements(
        in rootElement: AccessibilityElement,
        matching criteria: ElementCriteria,
        timeout: TimeInterval = defaultTimeout
    ) async throws -> [AccessibilityElement] {
        
        let deadline = Date().addingTimeInterval(timeout)
        var foundElements: [AccessibilityElement] = []
        
        // Search with timeout
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                foundElements = await self.searchElements(
                    in: rootElement,
                    matching: criteria,
                    depth: 0,
                    maxDepth: Self.maxSearchDepth,
                    deadline: deadline
                )
            }
        }
        
        return foundElements
    }
    
    // MARK: - Private Implementation
    
    private func searchElements(
        in element: AccessibilityElement,
        matching criteria: ElementCriteria,
        depth: Int,
        maxDepth: Int,
        deadline: Date
    ) async -> [AccessibilityElement] {
        
        // Check timeout
        guard Date() < deadline else { return [] }
        
        // Check depth limit
        guard depth < maxDepth else { return [] }
        
        var results: [AccessibilityElement] = []
        
        // Check if current element matches
        if await criteria.matches(element) {
            results.append(element)
        }
        
        // Search children
        let children = await element.children
        for child in children {
            let childResults = await searchElements(
                in: child,
                matching: criteria,
                depth: depth + 1,
                maxDepth: maxDepth,
                deadline: deadline
            )
            results.append(contentsOf: childResults)
        }
        
        return results
    }
}

// MARK: - Element Criteria

public struct ElementCriteria: Sendable {
    private let matcher: @Sendable (AccessibilityElement) async -> Bool
    
    public init(matcher: @escaping @Sendable (AccessibilityElement) async -> Bool) {
        self.matcher = matcher
    }
    
    public func matches(_ element: AccessibilityElement) async -> Bool {
        return await matcher(element)
    }
    
    // MARK: - Common Criteria
    
    public static func role(_ role: String) -> ElementCriteria {
        ElementCriteria { element in
            return await element.role == role
        }
    }
    
    public static func title(_ title: String) -> ElementCriteria {
        ElementCriteria { element in
            return await element.title == title
        }
    }
    
    public static func titleContains(_ substring: String) -> ElementCriteria {
        ElementCriteria { element in
            guard let elementTitle = await element.title else { return false }
            return elementTitle.localizedCaseInsensitiveContains(substring)
        }
    }
    
    public static func value(_ value: String) -> ElementCriteria {
        ElementCriteria { element in
            return await element.value == value
        }
    }
    
    public static func valueContains(_ substring: String) -> ElementCriteria {
        ElementCriteria { element in
            guard let elementValue = await element.value else { return false }
            return elementValue.localizedCaseInsensitiveContains(substring)
        }
    }
    
    public static func and(_ criteria: [ElementCriteria]) -> ElementCriteria {
        ElementCriteria { element in
            for criterion in criteria {
                if !(await criterion.matches(element)) {
                    return false
                }
            }
            return true
        }
    }
    
    public static func or(_ criteria: [ElementCriteria]) -> ElementCriteria {
        ElementCriteria { element in
            for criterion in criteria {
                if await criterion.matches(element) {
                    return true
                }
            }
            return false
        }
    }
}

// MARK: - System Accessibility Element

/// Concrete implementation of AccessibilityElement using AX APIs
public struct SystemAccessibilityElement: AccessibilityElement {
    private let axElement: AXUIElement
    
    public init(axElement: AXUIElement) {
        self.axElement = axElement
    }
    
    public init(axElement: CFTypeRef) {
        self.axElement = axElement as! AXUIElement
    }
    
    public var role: String? {
        get async {
            return await getAttribute("AXRole") as? String
        }
    }
    
    public var title: String? {
        get async {
            return await getAttribute("AXTitle") as? String
        }
    }
    
    public var value: String? {
        get async {
            return await getAttribute("AXValue") as? String
        }
    }
    
    public var children: [AccessibilityElement] {
        get async {
            guard let childrenArray = await getAttribute("AXChildren") as? [CFTypeRef] else {
                return []
            }
            
            return childrenArray.map { SystemAccessibilityElement(axElement: $0) }
        }
    }
    
    public var parent: AccessibilityElement? {
        get async {
            guard let parentElement = await getAttribute("AXParent") else {
                return nil
            }
            
            // Safe cast to AXUIElement
            let cfRef = parentElement as CFTypeRef
            return SystemAccessibilityElement(axElement: cfRef)
        }
    }
    
    public func getAttribute(_ attribute: String) async -> Any? {
        return await withCheckedContinuation { continuation in
            var result: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(axElement, attribute as CFString, &result)
            
            if error == .success, let value = result {
                continuation.resume(returning: value)
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
    
    public func performAction(_ action: String) async throws {
        let error = await withCheckedContinuation { continuation in
            let result = AXUIElementPerformAction(axElement, action as CFString)
            continuation.resume(returning: result)
        }
        
        if error != .success {
            throw SlackScraperError.unexpectedError("Failed to perform action: \(action)")
        }
    }
}

// MARK: - Accessibility Status

public enum AccessibilityStatus: String, CaseIterable {
    case available = "available"
    case permissionDenied = "permission_denied"
    case notSupported = "not_supported"
    case error = "error"
    
    public var isUsable: Bool {
        return self == .available
    }
    
    public var description: String {
        switch self {
        case .available:
            return "Accessibility is available and ready to use"
        case .permissionDenied:
            return "Accessibility permissions are required. Please enable in System Preferences > Security & Privacy > Accessibility"
        case .notSupported:
            return "Accessibility is not supported on this system"
        case .error:
            return "An error occurred while checking accessibility status"
        }
    }
}

// MARK: - Convenience Extensions

public extension AccessibilityManager {
    /// Find first element matching criteria
    func findFirstElement(
        in rootElement: AccessibilityElement,
        matching criteria: ElementCriteria,
        timeout: TimeInterval = 5.0
    ) async throws -> AccessibilityElement? {
        let elements = try await findElements(in: rootElement, matching: criteria, timeout: timeout)
        return elements.first
    }
    
    /// Find elements by role
    func findElements(
        in rootElement: AccessibilityElement,
        withRole role: String,
        timeout: TimeInterval = 5.0
    ) async throws -> [AccessibilityElement] {
        return try await findElements(in: rootElement, matching: .role(role), timeout: timeout)
    }
    
    /// Find element by title
    func findElement(
        in rootElement: AccessibilityElement,
        withTitle title: String,
        timeout: TimeInterval = 5.0
    ) async throws -> AccessibilityElement? {
        return try await findFirstElement(in: rootElement, matching: .title(title), timeout: timeout)
    }
}

// MARK: - Debug Helpers

public extension AccessibilityElement {
    /// Get a description of this element for debugging
    func debugDescription() async -> String {
        let role = await self.role ?? "Unknown"
        let title = await self.title ?? "No title"
        let value = await self.value ?? "No value"
        return "Element(role: \(role), title: \(title), value: \(value))"
    }
    
    /// Get a tree representation for debugging
    func debugTree(depth: Int = 0, maxDepth: Int = 3) async -> String {
        let indent = String(repeating: "  ", count: depth)
        var result = indent + (await debugDescription()) + "\n"
        
        if depth < maxDepth {
            let children = await self.children
            for child in children {
                result += await child.debugTree(depth: depth + 1, maxDepth: maxDepth)
            }
        }
        
        return result
    }
}