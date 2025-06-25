@preconcurrency import ApplicationServices
import Foundation

/// A protocol that provides any part of an Element that's necessary for a Parser to work. Parsers should exclusively
/// work on `ElementProtocol` types.
public protocol ElementProtocol: Sendable {
    func getValue() throws -> String?
    func getAttributeValue(_ attribute: Attribute) throws -> Sendable?
    func getAttributeValue(_ attribute: String) throws -> Sendable?
    func getChildren() throws -> [ElementProtocol]?
    func getAttributeValueCount(_ attribute: Attribute) throws -> Int?
    func getLabel() throws -> String?
    func getContents() throws -> [ElementProtocol]?
    func listAttributes() throws -> [String]
    func listActions() throws -> [String]
    func listParameterizedAttributes() throws -> [String]
    func getParent(atLevel level: Int) throws -> ElementProtocol?
}

public extension ElementProtocol {
    func has(role: Role) -> Bool {
        do {
            return try getAttributeValue(.role) as? Role == role
        } catch {
            return false
        }
    }

    func has(subrole: Subrole) -> Bool {
        do {
            return try getAttributeValue(.subrole) as? Subrole == subrole
        } catch {
            return false
        }
    }
}

/// Swift wrapper for a legacy ``AXUIElement``. A concrete implementation of the ElementProtocol that is connected to an
/// actual accessibility element.
public struct Element: ElementProtocol, Encodable {
    /// Legacy accessibility element.
    nonisolated let element: AXUIElement

    /// Creates an application element for the specified process identifier.
    /// - Parameter processIdentifier: Process identifier of the application.
    public init(processIdentifier: pid_t) {
        element = AXUIElementCreateApplication(processIdentifier)
        try? self.setTimeout(seconds: 5)
    }

    /// Wraps a ``AXUIElement``.
    /// - Parameter element: Legacy accessibility element to wrap.
    init(axUIElement element: AXUIElement) {
        self.element = element
        try? self.setTimeout(seconds: 5)
    }

    /// Attempts to initialize from a legacy accessibility value.
    /// - Parameter value: Legacy accessibility value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        element = value as! AXUIElement
    }

    /// Sets the timeout of requests made to this element.
    /// - Parameter seconds: Timeout in seconds.
    public func setTimeout(seconds: Float) throws {
        let result = AXUIElementSetMessagingTimeout(element, seconds)
        let error = AccessError(result)
        switch error {
        case .success:
            break
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            print("Unexpected error setting timeout: \(error)")
        }
    }

    /// Fetches the number of values associated to an attribute.
    /// - Parameter attribute: Attribute to query.
    /// - Returns: Number of associated values.
    public func getAttributeValueCount(_ attribute: Attribute) throws -> Int? {
        var count = CFIndex(0)
        let result = AXUIElementGetAttributeValueCount(element, attribute.rawValue as CFString, &count)
        let error = AccessError(result)
        switch error {
        case .success:
            break
        case .attributeUnsupported, .noValue, .systemFailure, .illegalArgument:
            return nil
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            print("Unexpected error getting value count: \(error)")
            return nil
        }
        return Int(count)
    }

    /// Reads the value associated to a given attribute of this element.
    /// - Parameter attribute: Attribute whose value is to be read.
    /// - Returns: Value of the attribute, if any.
    public func getAttributeValue(_ attribute: Attribute) throws -> Sendable? {
        let output = try getAttributeValue(attribute.rawValue)
        if attribute == .role, let output = output as? String {
            return Role(rawValue: output)
        }
        if attribute == .subrole, let output = output as? String {
            return Subrole(rawValue: output)
        }
        return output
    }

    /// Creates a list of all the actions supported by this element.
    /// - Returns: List of actions.
    public func listActions() throws -> [String] {
        var actions: CFArray?
        let result = AXUIElementCopyActionNames(element, &actions)
        let error = AccessError(result)
        guard error == .success, let actions else {
            switch error {
            case .systemFailure, .illegalArgument:
                return []
            case .apiDisabled, .invalidElement, .notImplemented, .timeout:
                throw error
            default:
                print("Unexpected error reading actions: \(error)")
                return []
            }
        }
        return [String](axValue: actions as CFTypeRef) ?? []
    }

    /// Creates a list of all the attributes supported by this element.
    /// - Returns: List of attributes.
    public func listAttributes() throws -> [String] {
        // 1. Check that the element is likely valid by verifying its PID
        var pid: pid_t = 0
        let pidStatus = AXUIElementGetPid(element, &pid)
        if pidStatus != .success || pid == 0 {
            print("AXUIElement has invalid PID or process is gone")
            throw AccessError.invalidElement
        }

        // 2. Try to safely fetch attribute names in a protected context
        var attributes: CFArray?

        let success = withUnsafeMutablePointer(to: &attributes) { attributesPtr in
            let status = AXUIElementCopyAttributeNames(element, attributesPtr)
            return status == .success
        }

        // 3. Check if we succeeded and the array is valid
        guard success, let cfAttributes = attributes else {
            print("AXUIElementCopyAttributeNames failed — element may have been deallocated")
            throw AccessError.invalidElement
        }

        // 4. Convert CFArray to [String] safely
        guard let rawArray = cfAttributes as? [CFString] else {
            print("Failed to cast CFArray to [CFString]")
            return []
        }

        return rawArray.map { String($0) }
    }

    /// Reads the value associated to a given attribute of this element.
    /// - Parameter attribute: Attribute whose value is to be read.
    /// - Returns: Value of the attribute, if any.
    public func getAttributeValue(_ attribute: String) throws -> Sendable? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        let error = AccessError(result)
        switch error {
        case .success:
            break
        case .attributeUnsupported, .noValue, .systemFailure, .illegalArgument:
            return nil
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            print("Unexpected error getting attribute value: \(error)")
            return nil
        }
        guard let value else {
            return nil
        }
        return swiftConvert(axValue: value)
    }

    /// Lists the parameterized attributes available to this element.
    /// - Returns: List of parameterized attributes.
    public func listParameterizedAttributes() throws -> [String] {
        var parameterizedAttributes: CFArray?
        let result = AXUIElementCopyParameterizedAttributeNames(element, &parameterizedAttributes)
        let error = AccessError(result)
        guard error == .success, let parameterizedAttributes else {
            switch error {
            case .apiDisabled, .invalidElement, .notImplemented, .timeout:
                throw error
            default:
                print("Unexpected error reading parameterized attributes: \(error)")
                return []
            }
        }
        return [String](axValue: parameterizedAttributes) ?? []
    }

    /// Looks for an element parent at a given level above current element.
    /// - Parameters:
    ///   - level: Number of levels to traverse up in accessibility tree.
    /// - Returns: Parent element at specified level if any were found. Returns 'nil' if no parent element was found at
    /// any level.
    public func getParent(atLevel level: Int = 1) throws -> (any ElementProtocol)? {
        guard level > 0 else { return self }

        let nextLevelParent = try getAttributeValue(.parentElement) as? any ElementProtocol
        guard let nextLevelParent else { return nil }

        return try nextLevelParent.getParent(atLevel: level - 1)
    }
}

public extension Element {
    /// Maximum number of children to fetch for an element
    static var maxChildrenCount: Int = 1000

    /// Maximum number of characters to fetch for a value
    static var maxValueCount: Int = 1_000_000

    /// Safely fetches contents of this element, respecting maximum count limits
    /// - Returns: Array of content elements, or nil if count exceeds limits or errors occur
    func getContents() throws -> [ElementProtocol]? {
        // First check the count
        guard let contentsCount = try getAttributeValueCount(.contents) else {
            return nil
        }

        // Verify against maximum allowed
        guard contentsCount <= Self.maxChildrenCount else {
            print("Warning: Contents count \(contentsCount) exceeds maximum \(Self.maxChildrenCount)")
            return nil
        }

        // Fetch the contents if count is acceptable
        return try getAttributeValue(.contents) as? [ElementProtocol]
    }

    /// Safely fetches children of this element, respecting maximum count limits
    /// - Returns: Array of child elements, or nil if count exceeds limits or errors occur
    func getChildren() throws -> [ElementProtocol]? {
        // First check the count
        guard let childrenCount = try getAttributeValueCount(.childElements) else {
            return nil
        }

        // Verify against maximum allowed
        guard childrenCount <= Self.maxChildrenCount else {
            print("Warning: Children count \(childrenCount) exceeds maximum \(Self.maxChildrenCount)")
            return nil
        }

        // Fetch the children if count is acceptable
        return try getAttributeValue(.childElements) as? [ElementProtocol]
    }

    /// Safely fetches the value of this element, respecting maximum character count limits
    /// - Returns: The element's value as a string, or nil if count exceeds limits or errors occur
    func getValue() throws -> String? {
        // Check character count if available
        if let charCount = try getAttributeValue(.numberOfCharacters) as? NSNumber,
           charCount.intValue > Self.maxValueCount {
            print("Warning: Character count \(charCount) exceeds maximum \(Self.maxValueCount)")
            return nil
        }

        // Try to get the value or value description
        var value: Any? = try getAttributeValue(.value)
        if value == nil {
            value = try getAttributeValue(.valueDescription) as? String
        }

        // Convert the value to string based on type
        switch value {
        case let string as String:
            return string
        case let attributedString as AttributedString:
            return String(attributedString.characters)
        case let url as URL:
            return url.absoluteString
        default:
            return nil
        }
    }

    /// Gets the label for this element by checking various attributes
    /// - Returns: The element's label as a string, or nil if not found
    func getLabel() throws -> String? {
        // Try title first
        if let title = try getAttributeValue(.title) as? String,
           !title.isEmpty {
            return title
        }

        // Try title element
        if let titleElement = try getAttributeValue(.titleElement) as? ElementProtocol {
            return try titleElement.getValue()
        }

        // Finally try description
        if let description = try getAttributeValue(.description) as? String,
           !description.isEmpty {
            return description
        }

        return nil
    }
}

extension Element: Hashable {
    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(element.hashValue)
    }

    public nonisolated static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.element == rhs.element
    }
}

extension Element: Legacy {
    var axValue: CFTypeRef {
        return element
    }
}

extension Element {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // Encode as a simplified representation since AXUIElement is not directly encodable
        let description = String(describing: element)
        try container.encode(description)
    }
}