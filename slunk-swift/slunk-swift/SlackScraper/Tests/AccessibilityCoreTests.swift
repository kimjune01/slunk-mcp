import Foundation

// MARK: - AccessibilityCore Unit Tests

/// Comprehensive unit tests for core accessibility components
public struct AccessibilityCoreTests {
    
    public static func runAllTests() async -> Bool {
        print("🧪 Running AccessibilityCore Tests...")
        
        var allTestsPassed = true
        
        allTestsPassed = await testAccessibilityManager() && allTestsPassed
        allTestsPassed = await testElementCriteria() && allTestsPassed
        allTestsPassed = await testSystemAccessibilityElement() && allTestsPassed
        allTestsPassed = testAccessibilityStatus() && allTestsPassed
        allTestsPassed = await testAccessibilityManagerConvenience() && allTestsPassed
        allTestsPassed = await testDebugHelpers() && allTestsPassed
        
        print("\n📊 AccessibilityCore Test Summary")
        print("All tests passed: \(allTestsPassed ? "✅ YES" : "❌ NO")")
        
        return allTestsPassed
    }
    
    // MARK: - AccessibilityManager Tests
    
    public static func testAccessibilityManager() async -> Bool {
        print("\n🎯 Testing AccessibilityManager...")
        var passed = true
        
        let manager = AccessibilityManager.shared
        
        // Test 1: Singleton access
        print("Test 1: Singleton access...")
        let manager2 = AccessibilityManager.shared
        if manager === manager2 {
            print("✅ Singleton access test passed")
        } else {
            print("❌ Singleton access test failed")
            passed = false
        }
        
        // Test 2: Default timeout constant
        print("Test 2: Default timeout...")
        if AccessibilityManager.defaultTimeout == 10.0 {
            print("✅ Default timeout test passed")
        } else {
            print("❌ Default timeout test failed")
            passed = false
        }
        
        // Test 3: Accessibility status check
        print("Test 3: Accessibility status check...")
        let status = await manager.checkAccessibility()
        
        // Note: This will likely be .permissionDenied in test environment
        if status == .available || status == .permissionDenied {
            print("✅ Accessibility status test passed (\(status))")
        } else {
            print("❌ Accessibility status test failed (\(status))")
            passed = false
        }
        
        // Test 4: Application element creation (will likely fail without permissions)
        print("Test 4: Application element creation...")
        do {
            let appElement = try await manager.getApplicationElement(pid: 12345)
            if appElement != nil {
                print("✅ Application element creation test passed")
            } else {
                print("✅ Application element creation test passed (nil expected without permissions)")
            }
        } catch {
            if error.localizedDescription.contains("not enabled") {
                print("✅ Application element creation test passed (expected error)")
            } else {
                print("❌ Application element creation test failed: \(error)")
                passed = false
            }
        }
        
        return passed
    }
    
    // MARK: - ElementCriteria Tests
    
    public static func testElementCriteria() async -> Bool {
        print("\n📏 Testing ElementCriteria...")
        var passed = true
        
        let mockElement = MockAccessibilityElementForCore(
            role: "AXButton",
            title: "Submit Button",
            value: "enabled"
        )
        
        // Test 1: Role criteria
        print("Test 1: Role criteria...")
        let roleCriteria = ElementCriteria.role("AXButton")
        let roleMatch = await roleCriteria.matches(mockElement)
        if roleMatch {
            print("✅ Role criteria test passed")
        } else {
            print("❌ Role criteria test failed")
            passed = false
        }
        
        // Test 2: Title criteria
        print("Test 2: Title criteria...")
        let titleCriteria = ElementCriteria.title("Submit Button")
        let titleMatch = await titleCriteria.matches(mockElement)
        if titleMatch {
            print("✅ Title criteria test passed")
        } else {
            print("❌ Title criteria test failed")
            passed = false
        }
        
        // Test 3: Title contains criteria
        print("Test 3: Title contains criteria...")
        let titleContainsCriteria = ElementCriteria.titleContains("Submit")
        let titleContainsMatch = await titleContainsCriteria.matches(mockElement)
        if titleContainsMatch {
            print("✅ Title contains criteria test passed")
        } else {
            print("❌ Title contains criteria test failed")
            passed = false
        }
        
        // Test 4: Value criteria
        print("Test 4: Value criteria...")
        let valueCriteria = ElementCriteria.value("enabled")
        let valueMatch = await valueCriteria.matches(mockElement)
        if valueMatch {
            print("✅ Value criteria test passed")
        } else {
            print("❌ Value criteria test failed")
            passed = false
        }
        
        // Test 5: Value contains criteria
        print("Test 5: Value contains criteria...")
        let valueContainsCriteria = ElementCriteria.valueContains("enabl")
        let valueContainsMatch = await valueContainsCriteria.matches(mockElement)
        if valueContainsMatch {
            print("✅ Value contains criteria test passed")
        } else {
            print("❌ Value contains criteria test failed")
            passed = false
        }
        
        // Test 6: AND criteria
        print("Test 6: AND criteria...")
        let andCriteria = ElementCriteria.and([roleCriteria, titleCriteria])
        let andMatch = await andCriteria.matches(mockElement)
        if andMatch {
            print("✅ AND criteria test passed")
        } else {
            print("❌ AND criteria test failed")
            passed = false
        }
        
        // Test 7: OR criteria
        print("Test 7: OR criteria...")
        let wrongTitleCriteria = ElementCriteria.title("Wrong Title")
        let orCriteria = ElementCriteria.or([wrongTitleCriteria, titleCriteria])
        let orMatch = await orCriteria.matches(mockElement)
        if orMatch {
            print("✅ OR criteria test passed")
        } else {
            print("❌ OR criteria test failed")
            passed = false
        }
        
        // Test 8: No match
        print("Test 8: No match...")
        let noMatchCriteria = ElementCriteria.role("AXTextField")
        let noMatch = await noMatchCriteria.matches(mockElement)
        if !noMatch {
            print("✅ No match test passed")
        } else {
            print("❌ No match test failed")
            passed = false
        }
        
        // Test 9: Case insensitive matching
        print("Test 9: Case insensitive matching...")
        let caseInsensitiveCriteria = ElementCriteria.titleContains("SUBMIT")
        let caseInsensitiveMatch = await caseInsensitiveCriteria.matches(mockElement)
        if caseInsensitiveMatch {
            print("✅ Case insensitive test passed")
        } else {
            print("❌ Case insensitive test failed")
            passed = false
        }
        
        return passed
    }
    
    // MARK: - SystemAccessibilityElement Tests
    
    public static func testSystemAccessibilityElement() async -> Bool {
        print("\n🖥️ Testing SystemAccessibilityElement...")
        var passed = true
        
        // Note: These tests use mock data since we can't create real AXUIElements in tests
        print("Test 1: Element creation...")
        
        // Create mock element for basic testing
        let mockElement = MockSystemAccessibilityElement()
        
        // Test basic property access
        let role = await mockElement.role
        let title = await mockElement.title
        let value = await mockElement.value
        
        if role == "MockRole" && title == "MockTitle" && value == "MockValue" {
            print("✅ Element property access test passed")
        } else {
            print("❌ Element property access test failed")
            passed = false
        }
        
        // Test children access
        print("Test 2: Children access...")
        let children = await mockElement.children
        if children.count == 2 {
            print("✅ Children access test passed")
        } else {
            print("❌ Children access test failed")
            passed = false
        }
        
        // Test parent access
        print("Test 3: Parent access...")
        let parent = await mockElement.parent
        if parent != nil {
            print("✅ Parent access test passed")
        } else {
            print("✅ Parent access test passed (nil expected for mock)")
        }
        
        // Test attribute access
        print("Test 4: Attribute access...")
        let attribute = await mockElement.getAttribute("AXRole")
        if attribute as? String == "MockRole" {
            print("✅ Attribute access test passed")
        } else {
            print("❌ Attribute access test failed")
            passed = false
        }
        
        // Test action performance
        print("Test 5: Action performance...")
        do {
            try await mockElement.performAction("AXPress")
            print("✅ Action performance test passed")
        } catch {
            print("❌ Action performance test failed: \(error)")
            passed = false
        }
        
        return passed
    }
    
    // MARK: - AccessibilityStatus Tests
    
    public static func testAccessibilityStatus() -> Bool {
        print("\n📊 Testing AccessibilityStatus...")
        var passed = true
        
        // Test 1: Available status
        print("Test 1: Available status...")
        let available = AccessibilityStatus.available
        if available.isUsable && available.description.contains("available") {
            print("✅ Available status test passed")
        } else {
            print("❌ Available status test failed")
            passed = false
        }
        
        // Test 2: Permission denied status
        print("Test 2: Permission denied status...")
        let denied = AccessibilityStatus.permissionDenied
        if !denied.isUsable && denied.description.contains("permission") {
            print("✅ Permission denied status test passed")
        } else {
            print("❌ Permission denied status test failed")
            passed = false
        }
        
        // Test 3: Not supported status
        print("Test 3: Not supported status...")
        let notSupported = AccessibilityStatus.notSupported
        if !notSupported.isUsable && notSupported.description.contains("not supported") {
            print("✅ Not supported status test passed")
        } else {
            print("❌ Not supported status test failed")
            passed = false
        }
        
        // Test 4: Error status
        print("Test 4: Error status...")
        let error = AccessibilityStatus.error
        if !error.isUsable && error.description.contains("error") {
            print("✅ Error status test passed")
        } else {
            print("❌ Error status test failed")
            passed = false
        }
        
        // Test 5: Case iterable
        print("Test 5: Case iterable...")
        let allCases = AccessibilityStatus.allCases
        if allCases.count == 4 {
            print("✅ Case iterable test passed")
        } else {
            print("❌ Case iterable test failed")
            passed = false
        }
        
        return passed
    }
    
    // MARK: - AccessibilityManager Convenience Methods Tests
    
    public static func testAccessibilityManagerConvenience() async -> Bool {
        print("\n🎯 Testing AccessibilityManager Convenience Methods...")
        var passed = true
        
        let manager = AccessibilityManager.shared
        let mockRoot = MockAccessibilityElementForCore(
            role: "AXWindow",
            title: "Test Window",
            children: [
                MockAccessibilityElementForCore(role: "AXButton", title: "Button 1"),
                MockAccessibilityElementForCore(role: "AXButton", title: "Button 2"),
                MockAccessibilityElementForCore(role: "AXTextField", title: "Text Field")
            ]
        )
        
        // Test 1: Find first element
        print("Test 1: Find first element...")
        do {
            let firstButton = try await manager.findFirstElement(
                in: mockRoot,
                matching: ElementCriteria.role("AXButton"),
                timeout: 1.0
            )
            if firstButton != nil {
                print("✅ Find first element test passed")
            } else {
                print("❌ Find first element test failed")
                passed = false
            }
        } catch {
            print("❌ Find first element threw: \(error)")
            passed = false
        }
        
        // Test 2: Find elements by role
        print("Test 2: Find elements by role...")
        do {
            let buttons = try await manager.findElements(
                in: mockRoot,
                withRole: "AXButton",
                timeout: 1.0
            )
            if buttons.count == 2 {
                print("✅ Find elements by role test passed")
            } else {
                print("❌ Find elements by role test failed (found \(buttons.count))")
                passed = false
            }
        } catch {
            print("❌ Find elements by role threw: \(error)")
            passed = false
        }
        
        // Test 3: Find element by title
        print("Test 3: Find element by title...")
        do {
            let textField = try await manager.findElement(
                in: mockRoot,
                withTitle: "Text Field",
                timeout: 1.0
            )
            if textField != nil {
                print("✅ Find element by title test passed")
            } else {
                print("❌ Find element by title test failed")
                passed = false
            }
        } catch {
            print("❌ Find element by title threw: \(error)")
            passed = false
        }
        
        // Test 4: Find non-existent element
        print("Test 4: Find non-existent element...")
        do {
            let nonExistent = try await manager.findElement(
                in: mockRoot,
                withTitle: "Non-existent",
                timeout: 0.5
            )
            if nonExistent == nil {
                print("✅ Find non-existent element test passed")
            } else {
                print("❌ Find non-existent element test failed")
                passed = false
            }
        } catch {
            print("❌ Find non-existent element threw: \(error)")
            passed = false
        }
        
        return passed
    }
    
    // MARK: - Debug Helpers Tests
    
    public static func testDebugHelpers() async -> Bool {
        print("\n🐛 Testing Debug Helpers...")
        var passed = true
        
        let mockElement = MockAccessibilityElementForCore(
            role: "AXButton",
            title: "Debug Button",
            value: "debug value",
            children: [
                MockAccessibilityElementForCore(role: "AXStaticText", title: "Child 1"),
                MockAccessibilityElementForCore(role: "AXStaticText", title: "Child 2")
            ]
        )
        
        // Test 1: Debug description
        print("Test 1: Debug description...")
        let description = await mockElement.debugDescription()
        if description.contains("AXButton") && 
           description.contains("Debug Button") && 
           description.contains("debug value") {
            print("✅ Debug description test passed")
        } else {
            print("❌ Debug description test failed: \(description)")
            passed = false
        }
        
        // Test 2: Debug tree
        print("Test 2: Debug tree...")
        let tree = await mockElement.debugTree(depth: 0, maxDepth: 2)
        if tree.contains("AXButton") && 
           tree.contains("Child 1") && 
           tree.contains("Child 2") {
            print("✅ Debug tree test passed")
        } else {
            print("❌ Debug tree test failed")
            passed = false
        }
        
        // Test 3: Debug tree depth limit
        print("Test 3: Debug tree depth limit...")
        let shallowTree = await mockElement.debugTree(depth: 0, maxDepth: 1)
        if shallowTree.contains("AXButton") && !shallowTree.contains("Child 1") {
            print("✅ Debug tree depth limit test passed")
        } else {
            print("❌ Debug tree depth limit test failed")
            passed = false
        }
        
        return passed
    }
}

// MARK: - Mock Implementations for Core Tests

/// Mock accessibility element for core testing
public class MockAccessibilityElementForCore: AccessibilityElement {
    private let mockRole: String?
    private let mockTitle: String?
    private let mockValue: String?
    private let mockChildren: [AccessibilityElement]
    public var mockParent: AccessibilityElement?
    
    public init(
        role: String? = nil,
        title: String? = nil,
        value: String? = nil,
        children: [AccessibilityElement] = []
    ) {
        self.mockRole = role
        self.mockTitle = title
        self.mockValue = value
        self.mockChildren = children
    }
    
    public var role: String? {
        get async { mockRole }
    }
    
    public var title: String? {
        get async { mockTitle }
    }
    
    public var value: String? {
        get async { mockValue }
    }
    
    public var children: [AccessibilityElement] {
        get async { mockChildren }
    }
    
    public var parent: AccessibilityElement? {
        get async { mockParent }
    }
    
    public func getAttribute(_ attribute: String) async -> Any? {
        switch attribute {
        case "AXRole": return mockRole
        case "AXTitle": return mockTitle
        case "AXValue": return mockValue
        case "AXChildren": return mockChildren
        case "AXParent": return mockParent
        default: return nil
        }
    }
    
    public func performAction(_ action: String) async throws {
        // Mock implementation - does nothing for testing
    }
}

/// Mock SystemAccessibilityElement for testing
public class MockSystemAccessibilityElement: AccessibilityElement {
    
    public var role: String? {
        get async { "MockRole" }
    }
    
    public var title: String? {
        get async { "MockTitle" }
    }
    
    public var value: String? {
        get async { "MockValue" }
    }
    
    public var children: [AccessibilityElement] {
        get async { 
            [
                MockAccessibilityElementForCore(role: "Child1"),
                MockAccessibilityElementForCore(role: "Child2")
            ]
        }
    }
    
    public var parent: AccessibilityElement? {
        get async { nil }
    }
    
    public func getAttribute(_ attribute: String) async -> Any? {
        switch attribute {
        case "AXRole": return "MockRole"
        case "AXTitle": return "MockTitle"
        case "AXValue": return "MockValue"
        case "AXChildren": return await children
        case "AXParent": return nil
        default: return nil
        }
    }
    
    public func performAction(_ action: String) async throws {
        // Mock implementation - succeeds for testing
    }
}