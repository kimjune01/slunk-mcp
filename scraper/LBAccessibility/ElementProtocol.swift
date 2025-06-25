@preconcurrency import ApplicationServices

import LBMetrics

/// A protocol that provides any part of an Element that's necessary for a Parser to work. Parsers should exclusively
/// work on `ElementProtocol` types.
@Accessibility
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

public extension ElementProtocol {
    /// Loops through children to find element with .staticText role and specified string as value
    /// - Parameters:
    ///   - value: String that is expected to be a child element's value.
    /// - Returns: Single child .staticText element if found.
    func findTextElementChild(withValue value: String) throws -> ElementProtocol? {
        let children = try getChildren()

        let textElement = try children?.first(where: { child in
            let childElementRole = try child.getAttributeValue(.role) as? Role ?? .unknown
            let childElementValue = try child.getValue()

            return childElementRole == .staticText && childElementValue == value
        })

        return textElement
    }

    /// Loops through children to find element with .button role and specified string as label
    /// - Parameters:
    ///   - label: String that is expected to be a child element's label.
    /// - Returns: Single child .button element if found.
    func findButtonElementChild(labeled label: String) throws -> ElementProtocol? {
        let children = try getChildren()

        let buttonElement = try children?.first(where: { child in
            let childElementRole = try child.getAttributeValue(.role) as? Role ?? .unknown
            let childElementLabel = try child.getLabel()

            return childElementRole == .button && childElementLabel == label
        })

        return buttonElement
    }
}

/// Swift wrapper for a legacy ``AXUIElement``. A concrete implementation of the ElementProtocol that is connected to an
/// actual accessibility element.
@Accessibility public struct Element: ElementProtocol {
    /// Legacy accessibility element.
    nonisolated let element: AXUIElement

    /// Creates a system-wide element.
    public init() {
        element = AXUIElementCreateSystemWide()
        try? self.setTimeout(seconds: 5)
    }

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

    /// Retrieves the accessibility element at a specific screen position.
    /// - Parameters:
    ///   - x: The x-coordinate in screen coordinates.
    ///   - y: The y-coordinate in screen coordinates.
    /// - Returns: An Element at the specified position, or nil if no element is found.
    /// - Throws: AccessError if there's an issue with the accessibility API.
    public func elementAtPosition(x: Float, y: Float) throws -> Element? {
        // Variable to hold the returned element
        var resultElement: AXUIElement?

        // Call the system API to find an element at the specified position
        let result = AXUIElementCopyElementAtPosition(element, x, y, &resultElement)
        let error = AccessError(result)

        switch error {
        case .success:
            // If successful but no element was found, return nil
            guard let resultElement else {
                return nil
            }
            // Convert the AXUIElement to our Element type and return it
            return Element(axUIElement: resultElement)
        case .systemFailure, .illegalArgument:
            // For non-critical errors, just return nil (no element found)
            return nil
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            // For serious accessibility issues, throw the error
            throw error
        default:
            // For unexpected errors, log and crash (consistent with other methods)
            Log.error("Unexpected error getting element at position (\(x), \(y))", error: error)
            fatalError("Unexpected error getting element at position (\(x), \(y)): \(error)")
        }
    }

    /// Creates an element referencing the application of the specified element.
    /// - Returns: Application element.
    public func getApplication() throws -> ElementProtocol {
        let processIdentifier = try getProcessIdentifier()
        return Element(processIdentifier: processIdentifier)
    }

    /// Fetches the process identifier of this element.
    /// - Returns: Process identifier.
    public func getProcessIdentifier() throws -> pid_t {
        var processIdentifier = pid_t(0)
        let result = AXUIElementGetPid(element, &processIdentifier)
        let error = AccessError(result)
        switch error {
        case .success:
            break
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            Log.error("Unexpected error reading an accessibility element's process identifier", error: error)
            fatalError("Unexpected error reading an accessibility element's process identifier: \(error)")
        }
        return processIdentifier
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
            Log.error(
                "Unexpected error setting an accessibility element's request timeout to \(seconds) seconds",
                error: error
            )
            assertionFailure(
                "Unexpected error setting an accessibility element's request timeout to \(seconds) seconds: \(error)"
            )
        }
    }

    /// Dumps this element to a data structure suitable to be encoded and serialized.
    /// - Parameters:
    ///   - recursiveParents: Whether to recursively dump this element's parents.
    ///   - recursiveChildren: Whether to recursively dump this element's children.
    /// - Returns: Serializable element structure.
    public func dump(recursiveParents: Bool, recursiveChildren: Bool) async -> Any {
        do {
            var root = [String: Any]()
            let attributes = try listAttributes()
            await Task.yield()
            var attributeValues = [String: Any]()
            for attribute in attributes {
                guard let value = try getAttributeValue(attribute) else {
                    continue
                }
                attributeValues[attribute] = value
                await Task.yield()
            }
            root["attributes"] = attributeValues
            guard attributeValues[Attribute.role.rawValue] as? String != Role.systemWide.rawValue else {
                return root
            }
            let parameterizedAttributes = try listParameterizedAttributes()
            root["parameterizedAttributes"] = parameterizedAttributes
            await Task.yield()
            let actions = try listActions()
            root["actions"] = actions
            await Task.yield()
            if recursiveParents, let parent = try getAttributeValue(.parentElement) as? Self {
                root["parent"] = await parent.dump(recursiveParents: true, recursiveChildren: false)
            }
            await Task.yield()
            if recursiveChildren, let children = try getAttributeValue(.childElements) as? [Legacy] {
                var resultingChildren = [Any]()
                await Task.yield()
                for child in children {
                    if let child = child as? Self {
                        let child = await child.dump(recursiveParents: false, recursiveChildren: true)
                        resultingChildren.append(child)
                        continue
                    }
                    resultingChildren.append(child)
                    await Task.yield()
                }
                root["children"] = resultingChildren
            }
            return root
        } catch {
            return error
        }
    }

    /// Retrieves the set of attributes supported by this element.
    /// - Returns: Set of attributes.
    public func getAttributeSet() throws -> Set<Attribute> {
        let attributes = try listAttributes()
        return Set(attributes.lazy.map({ Attribute(rawValue: $0) }))
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
            Log.error(
                "Unexpected error getting value count for accessibility element attribute with identifier \(attribute)",
                error: error
            )
            fatalError(
                "Unexpected error getting value count for accessibility element attribute with identifier \(attribute): \(error)"
            )
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

    /// Writes a value to the specified attribute of this element.
    /// - Parameters:
    ///   - attribute: Attribute to be written.
    ///   - value: Value to write.
    public func setAttributeValue(_ attribute: Attribute, value: Sendable) throws {
        guard let value = value as? Legacy else {
            throw AccessError.illegalArgument
        }
        return try setAttributeValue(attribute.rawValue, value: value)
    }

    /// Retrieves the set of parameterized attributes supported by this element.
    /// - Returns: Set of parameterized attributes.
    public func getParameterizedAttributeSet() throws -> Set<ParameterizedAttribute> {
        let attributes = try listParameterizedAttributes()
        return Set(attributes.lazy.map({ ParameterizedAttribute(rawValue: $0) }))
    }

    /// Queries the specified parameterized attribute of this element.
    /// - Parameters:
    ///   - attribute: Parameterized attribute to query.
    ///   - input: Input value.
    /// - Returns: Output value.
    public func queryParameterizedAttributeValue(
        _ attribute: ParameterizedAttribute,
        input: Sendable
    ) throws -> Sendable? {
        guard let input = input as? Legacy else {
            throw AccessError.illegalArgument
        }
        return try queryParameterizedAttributeValue(attribute.rawValue, input: input)
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
                Log.error("Unexpected error reading an accessibility elenet's action identifiers", error: error)
                fatalError("Unexpected error reading an accessibility elenet's action identifiers: \(error)")
            }
        }
        return [String](axValue: actions as CFTypeRef) ?? []
    }

    /// Queries for a localized description of the specified action.
    /// - Parameter action: Action to query.
    /// - Returns: Description of the action.
    public func describeAction(_ action: String) throws -> String? {
        var description: CFString?
        let result = AXUIElementCopyActionDescription(element, action as CFString, &description)
        let error = AccessError(result)
        switch error {
        case .success:
            break
        case .actionUnsupported, .illegalArgument, .systemFailure:
            return nil
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            Log.error(
                "Unexpected error reading an accessibility element's description for action identifier \(action)",
                error: error
            )
            fatalError(
                "Unexpected error reading an accessibility element's description for action identifier \(action)"
            )
        }
        guard let description else {
            return nil
        }
        return description as String
    }

    /// Performs the specified action on this element.
    /// - Parameter action: Action to perform.
    public func performAction(_ action: String) throws {
        let result = AXUIElementPerformAction(element, action as CFString)
        let error = AccessError(result)
        switch error {
        case .success, .systemFailure, .illegalArgument:
            break
        case .actionUnsupported, .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            Log.error(
                "Unexpected error performing accessibility element action with identifier \(action)",
                error: error
            )
            fatalError("Unexpected error performing accessibility element action with identifier \(action): \(error)")
        }
    }

    /// Creates a list of all the attributes supported by this element.
    /// - Returns: List of attributes.
    public func listAttributes() throws -> [String] {
        // 1. Check that the element is likely valid by verifying its PID
        var pid: pid_t = 0
        let pidStatus = AXUIElementGetPid(element, &pid)
        if pidStatus != .success || pid == 0 {
            Log.error("AXUIElement has invalid PID or process is gone")
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
            Log.error("AXUIElementCopyAttributeNames failed — element may have been deallocated")
            throw AccessError.invalidElement
        }

        // 4. Convert CFArray to [String] safely
        guard let rawArray = cfAttributes as? [CFString] else {
            Log.error("Failed to cast CFArray to [CFString]")
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
            Log.error(
                "Unexpected error getting value for accessibility element attribute with identifier \(attribute)",
                error: error
            )
            fatalError(
                "Unexpected error getting value for accessibility element attribute with identifier \(attribute): \(error)"
            )
        }
        guard let value else {
            return nil
        }
        return swiftConvert(axValue: value)
    }

    /// Writes a value to the specified attribute of this element.
    /// - Parameters:
    ///   - attribute: Attribute to be written.
    ///   - value: Value to write.
    private func setAttributeValue(_ attribute: String, value: Legacy) throws {
        let result = AXUIElementSetAttributeValue(element, attribute as CFString, value.axValue)
        let error = AccessError(result)
        switch error {
        case .success, .systemFailure, .attributeUnsupported, .illegalArgument:
            break
        case .apiDisabled, .invalidElement, .notEnoughPrecision, .notImplemented, .timeout:
            throw error
        default:
            Log.error(
                "Unexpected error setting accessibility element attribute with identifier \(attribute)",
                error: error
            )
            assertionFailure(
                "Unexpected error setting accessibility element attribute with identifier \(attribute): \(error)"
            )
        }
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
                Log.error(
                    "Unexpected error reading an accessibility element's parameterized attribute identifiers",
                    error: error
                )
                fatalError(
                    "Unexpected error reading an accessibility element's parameterized attribute identifiers: \(error)"
                )
            }
        }
        return [String](axValue: parameterizedAttributes) ?? []
    }

    /// Queries the specified parameterized attribute of this element.
    /// - Parameters:
    ///   - attribute: Parameterized attribute to query.
    ///   - input: Input value.
    /// - Returns: Output value.
    private func queryParameterizedAttributeValue(_ attribute: String, input: Legacy) throws -> Sendable? {
        var output: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            attribute as CFString,
            input.axValue as CFTypeRef,
            &output
        )
        let error = AccessError(result)
        guard error == .success, let output else {
            switch error {
            case .noValue, .parameterizedAttributeUnsupported, .systemFailure, .illegalArgument:
                return nil
            case .apiDisabled, .invalidElement, .notEnoughPrecision, .notImplemented, .timeout:
                throw error
            default:
                Log.error(
                    "Unexpected error querying parameterized accessibility element attribute with identifier \(attribute) and input value \(input)",
                    error: error
                )
                fatalError(
                    "Unexpected error querying parameterized accessibility element attribute with identifier \(attribute) and input value \(input): \(error)"
                )
            }
        }
        return swiftConvert(axValue: output)
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

    /// Checks the accessibility trusted status for this process.
    /// - Returns: Whether this process has accessibility privileges.
    @MainActor public static func checkProcessTrustedStatus() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Checks the accessibility trusted status for this process, and prompts the user if no status information is
    /// available.
    /// - Returns: Whether this process has accessibility privileges.
    @MainActor public static func confirmProcessTrustedStatus() -> Bool {
        return AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt
                .takeUnretainedValue() as String: true,
        ] as CFDictionary)
    }
}

extension Element: Hashable {
    public nonisolated func hash(into hasher: inout Hasher) {
        let hashValue = Accessibility.Executor.shared.perform(job: { element.hashValue })
        hasher.combine(hashValue)
    }

    public nonisolated static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
        return Accessibility.Executor.shared.perform(job: { lhs.element == rhs.element })
    }
}

extension Element: Encodable {
    public nonisolated func encode(to encoder: any Encoder) throws {
        let description = Accessibility.Executor.shared.perform { @Sendable [unowned element] () -> String in
            let id = CFGetTypeID(element)
            let name = CFCopyTypeIDDescription(id) as? String ?? "Unknown Core Foundation type with ID \(id)"
            let description = CFCopyDescription(element) as? String ?? "No description available"
            var processIdentifier = pid_t.zero
            guard AXUIElementGetPid(element, &processIdentifier) == .success else {
                return "\(name): \(description)"
            }
            return "\(name) (PID: \(processIdentifier): \(description)"
        }
        try description.encode(to: encoder)
    }
}

extension Element: Legacy {
    var axValue: CFTypeRef {
        return element
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
            debugPrint("Warning: Contents count \(contentsCount) exceeds maximum \(Self.maxChildrenCount)")
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
            debugPrint("Warning: Children count \(childrenCount) exceeds maximum \(Self.maxChildrenCount)")
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
            debugPrint("Warning: Character count \(charCount) exceeds maximum \(Self.maxValueCount)")
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

    func debugPrintAttributes() {
        var result = ""
        do {
            let attributes = try listAttributes()
            for attribute in attributes {
                result += attribute + ": "
                guard let value = try getAttributeValue(attribute) as? String else {
                    result += "\n"
                    continue
                }
                result += value + "\n"
            }
        } catch {
            // do nothing.
        }
        print(result)
    }
}

// Custom error types for better error handling
enum AccessibilityError: Error {
    case invalidElement
    case attributeNotFound
    case invalidAttributeValue
    case timeout
    case tooManyChildren(count: Int)
    case frameError
}

@Accessibility public final class ElementDump: @unchecked Sendable, CustomStringConvertible {
    public struct AttributeEntry: Sendable {
        let key: String
        let value: String

        init(key: String, value: Any) {
            self.key = key
            // Handle array values
            if let array = value as? [Any], array.isEmpty {
                self.value = "" // Empty array will be filtered out
            } else {
                self.value = String(describing: value)
            }
        }
    }

    public nonisolated let attributes: [AttributeEntry]
    public nonisolated let parameterizedAttributes: [String]?
    public nonisolated let actions: [String]?
    public nonisolated let parent: ElementDump?
    public nonisolated let children: [ElementDump]?

    public init(
        attributes: [String: Any],
        attributesToShow: Set<String>? = nil,
        parameterizedAttributes: [String]? = nil,
        parameterizedAttributesToShow: Set<String>? = nil,
        actions: [String]? = nil,
        parent: ElementDump? = nil,
        children: [ElementDump]? = nil,
        showParameterizedAttributes: Bool = false,
        showActions: Bool = false,
        skipEmpty: Bool = true
    ) {
        // Filter attributes based on attributesToShow if provided and remove empty strings and empty arrays
        let filteredAttributes: [String: Any]
        if let attributesToShow {
            filteredAttributes = attributes.filter {
                attributesToShow.contains($0.key) &&
                    (!ElementDump.isEmptyValue($0.value) || !skipEmpty)
            }
        } else {
            filteredAttributes = attributes.filter {
                !ElementDump.isEmptyValue($0.value) || !skipEmpty
            }
        }
        self.attributes = filteredAttributes.map { AttributeEntry(key: $0.key, value: $0.value) }

        // Handle parameterizedAttributes based on showParameterizedAttributes flag and filter if needed
        if showParameterizedAttributes {
            if let paramAttr = parameterizedAttributes,
               let paramToShow = parameterizedAttributesToShow {
                self.parameterizedAttributes = paramAttr.filter { paramToShow.contains($0) }
            } else {
                self.parameterizedAttributes = parameterizedAttributes
            }
        } else {
            self.parameterizedAttributes = nil
        }

        // Only show actions if requested
        self.actions = showActions ? actions : nil
        self.parent = parent
        self.children = children?.isEmpty == true ? nil : children
    }

    static func isEmptyValue(_ value: Any) -> Bool {
        if let array = value as? [Any] {
            return array.isEmpty
        }
        let stringValue = String(describing: value)
        return stringValue == "\"\"" || stringValue.isEmpty || stringValue == "[]"
    }

    public nonisolated var description: String {
        var output = "ElementDump {\n"

        if !attributes.isEmpty {
            output += formatSection(title: "Attributes", content: formatAttributes(attributes), indent: 1)
        }

        if let paramAttrs = parameterizedAttributes, !paramAttrs.isEmpty {
            output += formatSection(
                title: "Parameterized Attributes",
                content: paramAttrs.joined(separator: ", "),
                indent: 1
            )
        }

        if let actions, !actions.isEmpty {
            output += formatSection(title: "Actions", content: actions.joined(separator: ", "), indent: 1)
        }

        if let parent {
            output += formatSection(title: "Parent", content: parent.description, indent: 1)
        }

        if let children, !children.isEmpty {
            output += formatSection(title: "Children", content: formatChildren(children), indent: 1)
        }

        output += "}"
        return output
    }

    private nonisolated func formatSection(title: String, content: String, indent: Int) -> String {
        let indentation = String(repeating: "  ", count: indent)
        return "\(indentation)\(title):\n\(indentation)  \(content)\n"
    }

    private nonisolated func formatAttributes(_ attrs: [AttributeEntry]) -> String {
        attrs.map { entry in
            "\(entry.key): \(entry.value)"
        }.joined(separator: "\n    ")
    }

    private nonisolated func formatChildren(_ children: [ElementDump]) -> String {
        return "[\n    " + children.map { child in
            child.description.replacingOccurrences(of: "\n", with: "\n    ")
        }.joined(separator: ",\n    ") + "\n  ]"
    }
}

@Accessibility public extension ElementProtocol {
    /// Dumps this element to a Sendable structure
    /// - Parameters:
    ///   - recursiveParents: Whether to recursively dump this element's parents
    ///   - recursiveChildren: Whether to recursively dump this element's children
    ///   - attributesToShow: Optional set of attributes to include in the dump. If nil, shows all attributes.
    ///   - parameterizedAttributesToShow: Optional set of parameterized attributes to include in the dump. If nil,
    /// shows all parameterized attributes.
    ///   - showParameterizedAttributes: Whether to include parameterized attributes at all. Defaults to false.
    ///   - showActions: Whether to include actions in the dump. Defaults to false.
    /// - Returns: Sendable element structure
    func dumpSendable(
        recursiveParents: Bool = false,
        recursiveChildren: Bool = false,
        skipEmpty: Bool = true,
        attributesToShow: Set<String>? = nil,
        parameterizedAttributesToShow: Set<String>? = nil,
        showParameterizedAttributes: Bool = false,
        showActions: Bool = false
    ) throws -> ElementDump {
        var attributes: [String: Any] = [:]
        for attribute in try listAttributes() {
            if let attributesToShow,
               !attributesToShow.contains(attribute) {
                continue
            }

            guard let value = try getAttributeValue(attribute) else {
                continue
            }

            // Skip empty values
            if skipEmpty, ElementDump.isEmptyValue(value) {
                continue
            }

            attributes[attribute] = value
        }

        // Don't continue if this is the system-wide element
        if attributes[Attribute.role.rawValue] as? String == Role.systemWide.rawValue {
            return ElementDump(
                attributes: attributes,
                attributesToShow: attributesToShow,
                showParameterizedAttributes: showParameterizedAttributes,
                showActions: showActions,
                skipEmpty: skipEmpty
            )
        }

        let parameterizedAttributes: [String]?
        if showParameterizedAttributes {
            parameterizedAttributes = try listParameterizedAttributes()
        } else {
            parameterizedAttributes = nil
        }

        let actions: [String]?
        if showActions {
            actions = try listActions()
        } else {
            actions = nil
        }

        var parent: ElementDump?
        if recursiveParents,
           let parentElement = try getAttributeValue(.parentElement) as? Element {
            parent = try parentElement.dumpSendable(
                recursiveParents: true,
                recursiveChildren: false,
                skipEmpty: skipEmpty,
                attributesToShow: attributesToShow,
                parameterizedAttributesToShow: parameterizedAttributesToShow,
                showParameterizedAttributes: showParameterizedAttributes,
                showActions: showActions
            )
        }

        var children: [ElementDump]?
        if recursiveChildren,
           let childElements = try getChildren() {
            children = try childElements.map { child in
                try child.dumpSendable(
                    recursiveParents: false,
                    recursiveChildren: true,
                    skipEmpty: skipEmpty,
                    attributesToShow: attributesToShow,
                    parameterizedAttributesToShow: parameterizedAttributesToShow,
                    showParameterizedAttributes: showParameterizedAttributes,
                    showActions: showActions
                )
            }
        }

        return ElementDump(
            attributes: attributes,
            attributesToShow: attributesToShow,
            parameterizedAttributes: parameterizedAttributes,
            parameterizedAttributesToShow: parameterizedAttributesToShow,
            actions: actions,
            parent: parent,
            children: children,
            showParameterizedAttributes: showParameterizedAttributes,
            showActions: showActions,
            skipEmpty: skipEmpty
        )
    }

    func printDump() async throws {
        let attributesToShow: Set<String> = [
            "AXRole",
            "AXSubrole",
            "AXDescription",
            "AXTitle",
            "AXDOMClassList",
            "AXValue",
            "AXDOMIdentifier",
        ]

        let dump = try self.dumpSendable(
            recursiveParents: false,
            recursiveChildren: true,
            attributesToShow: attributesToShow,
            showParameterizedAttributes: false
        )
        print("==========dump==========")
        print(dump)
    }
}

// Helper extension for finding children
public extension ElementProtocol {
    func firstChild(withRole role: Role) async throws -> ElementProtocol? {
        try self.getChildren()?.first { $0.has(role: role) }
    }
}
