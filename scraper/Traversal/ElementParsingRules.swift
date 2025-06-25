import Foundation
import LBAccessibility
import LBMetrics

public typealias ElementMatcher = @Sendable (ElementProtocol) async -> Bool
public typealias ElementHandler = @Sendable (ElementProtocol) async -> Void
public typealias ElementTransform<T: Sendable> = @Sendable (ElementProtocol) async -> T?

public protocol CollectorProtocol: Sendable {
    associatedtype Item

    func add(_ element: ElementProtocol) async
    func getItems() async -> [Item]
    func getFirst() async -> Item?
    func isEmpty() async -> Bool
    func count() async -> Int
}

// MARK: - Base Generic Collector

/// Base actor that implements common functionality for all collectors
public actor BaseCollector<T: Sendable>: CollectorProtocol {
    private var items: [T] = []
    private let transform: ElementTransform<T>

    public init(transform: @escaping ElementTransform<T>) {
        self.transform = transform
    }

    /// Add an element to the collection
    public func add(_ element: ElementProtocol) async {
        if let newItem = await transform(element) {
            items.append(newItem)
        }
    }

    /// Get all collected items
    public func getItems() async -> [T] {
        return items
    }

    /// Get the first item or nil if empty
    public func getFirst() async -> T? {
        return items.first
    }

    /// Check if the collection is empty
    public func isEmpty() async -> Bool {
        return items.isEmpty
    }

    /// Get the count of items
    public func count() async -> Int {
        return items.count
    }

    /// Add items directly to the collection
    public func addItems(_ newItems: [T]) async {
        items.append(contentsOf: newItems)
    }

    /// Add a single item to the collection
    public func addItem(_ item: T) async {
        items.append(item)
    }
}

// MARK: - Common Collectors

/// Collector for Element objects
public typealias ElementCollector = BaseCollector<ElementProtocol>

/// Collector for text values
public typealias TextCollector = BaseCollector<String>

/// Collector for value or description
public typealias ValueOrDescriptionCollector = BaseCollector<String>

/// Collector for attributes
public typealias AttributeCollector<T: Sendable> = BaseCollector<T>

/// Collector for booleans
public typealias BooleanFlagCollector = BaseCollector<Bool>

public enum Collectors {
    public static func makeElementCollector() -> ElementCollector {
        return ElementCollector(transform: { element in element })
    }

    public static func makeTextCollector() -> TextCollector {
        return TextCollector(transform: { element in
            let value = try? await element.getValue()
            return value?.isEmpty == false ? value : nil
        })
    }

    public static func makeValueOrDescriptionCollector() -> ValueOrDescriptionCollector {
        return ValueOrDescriptionCollector(transform: { element in
            if let value = try? await element.getValue(), !value.isEmpty {
                return value
            } else if let description = try? await element.getAttributeValue(Attribute.description) as? String,
                      !description.isEmpty {
                return description
            }
            return ""
        })
    }

    public static func makeAttributeCollector<T: Sendable>(attribute: Attribute) -> AttributeCollector<T> {
        return AttributeCollector<T> { element in
            try? await element.getAttributeValue(attribute) as? T
        }
    }

    public static func makeBooleanFlagCollector(condition: @escaping ElementMatcher) -> BooleanFlagCollector {
        return BooleanFlagCollector(transform: condition)
    }
}

// MARK: - Rule Protocol & Implementation

public protocol RuleProtocol: Sendable {
    func apply(_ element: ElementProtocol) async -> Bool
}

public struct Rule: RuleProtocol, Sendable {
    let matcher: ElementMatcher
    let handler: ElementHandler

    public init(
        matcher: @escaping ElementMatcher,
        handler: @escaping ElementHandler
    ) {
        self.matcher = matcher
        self.handler = handler
    }

    public init(
        matcher: @escaping ElementMatcher,
        collector: some CollectorProtocol
    ) {
        self.matcher = matcher
        self.handler = { element in
            await collector.add(element)
        }
    }

    public func apply(_ element: ElementProtocol) async -> Bool {
        if await matcher(element) {
            await handler(element)
            return true
        }
        return false
    }
}

public struct AttributeMapRule<T: Equatable & Sendable & Hashable>: RuleProtocol, Sendable {
    let attribute: Attribute
    let handlers: [T: ElementHandler]
    let defaultHandler: ElementHandler?

    public init(
        attribute: Attribute,
        handlers: [T: ElementHandler],
        defaultHandler: ElementHandler? = nil
    ) {
        self.attribute = attribute
        self.handlers = handlers
        self.defaultHandler = defaultHandler
    }

    public func apply(_ element: ElementProtocol) async -> Bool {
        do {
            if let value = try await element.getAttributeValue(attribute) as? T {
                if let handler = handlers[value] {
                    await handler(element)
                    return true
                } else if let defaultHandler {
                    await defaultHandler(element)
                    return true
                }
            }
        } catch {
            Log.error("Error in AttributeMapRule: \(error)", error: error)
        }
        return false
    }
}

public struct CompositeRule: RuleProtocol, Sendable {
    let rules: [RuleProtocol]
    let mode: CompositionMode

    public enum CompositionMode: Sendable {
        case any // Succeeds if any rule matches
        case all // Succeeds only if all rules match
        case sequence // Applies rules in sequence, stops on first failure
    }

    public init(rules: [RuleProtocol], mode: CompositionMode = .any) {
        self.rules = rules
        self.mode = mode
    }

    public func apply(_ element: ElementProtocol) async -> Bool {
        switch mode {
        case .any:
            for rule in rules {
                if await rule.apply(element) {
                    return true
                }
            }
            return false

        case .all:
            for rule in rules {
                if !(await rule.apply(element)) {
                    return false
                }
            }
            return true

        case .sequence:
            for rule in rules {
                if !(await rule.apply(element)) {
                    return false
                }
            }
            return true
        }
    }
}

public enum Matchers {
    public static func hasAttribute(_ attribute: Attribute, substring: String) -> ElementMatcher {
        return { element in
            do {
                if let stringValue = try await element.getAttributeValue(attribute) as? String {
                    return stringValue.contains(substring)
                }
            } catch {
                Log.error("Error checking if attribute \(attribute) contains '\(substring)': \(error)", error: error)
            }
            return false
        }
    }

    public static func hasAttribute<T: Equatable & Sendable>(
        _ attribute: Attribute,
        equalTo value: T
    ) -> ElementMatcher {
        return { element in
            do {
                if let attrValue = try await element.getAttributeValue(attribute) as? T {
                    return attrValue == value
                }
            } catch {
                Log.error("Error checking attribute \(attribute): \(error)", error: error)
            }
            return false
        }
    }

    public static func hasAttribute<T: Equatable & Sendable>(
        _ attribute: Attribute,
        containsAny values: [T]
    ) -> ElementMatcher {
        return { element in
            do {
                if let attrValue = try await element.getAttributeValue(attribute) as? T {
                    return values.contains(attrValue)
                }
            } catch {
                Log.error("Error checking attribute \(attribute): \(error)", error: error)
            }
            return false
        }
    }

    public static func hasAttribute(_ attribute: Attribute) -> ElementMatcher {
        return { element in
            do {
                return try await element.getAttributeValue(attribute) != nil
            } catch {
                return false
            }
        }
    }

    public static func hasClass(_ className: String) -> ElementMatcher {
        return { element in
            do {
                guard let classList = try await element.getAttributeValue("AXDOMClassList") as? [String] else {
                    return false
                }
                return classList.contains(className)
            } catch {
                Log.error("Error checking class \(className): \(error)", error: error)
                return false
            }
        }
    }

    public static func hasClassContaining(_ substring: String) -> ElementMatcher {
        return { element in
            do {
                guard let classList = try await element.getAttributeValue("AXDOMClassList") as? [String] else {
                    return false
                }
                return classList.contains(where: { $0.contains(substring) })
            } catch {
                Log.error("Error checking class containing \(substring): \(error)", error: error)
                return false
            }
        }
    }

    public static func hasChild(matching childMatcher: @escaping ElementMatcher) -> ElementMatcher {
        return { element in
            do {
                guard let children = try await element.getChildren() else { return false }
                // Check if any child matches the condition
                for child in children {
                    if await childMatcher(child) {
                        return true
                    }
                }
                return false
            } catch {
                Log.error("Error checking children: \(error)", error: error)
                return false
            }
        }
    }

    // Async version for descendent checking
    public static func hasDescendant(
        matching matcher: @escaping ElementMatcher,
        maxDepth: Int = .max
    ) -> ElementMatcher {
        return { element in
            do {
                let collector = Collectors.makeTextCollector()
                let rule = Rule(matcher: matcher, collector: collector)
                try await element.traverse(
                    rules: [rule],
                    maxDepth: maxDepth,
                    terminateAfterAnyRule: true
                )
                let empty = await collector.isEmpty()
                return !empty
            } catch {
                Log.error("Error checking descendants: \(error)", error: error)
                return false
            }
        }
    }

    public static func not(_ matcher: @escaping ElementMatcher) -> ElementMatcher {
        return { element in
            !(await matcher(element))
        }
    }

    public static func all(_ matchers: [ElementMatcher]) -> ElementMatcher {
        return { element in
            for matcher in matchers {
                if !(await matcher(element)) {
                    return false
                }
            }
            return true
        }
    }

    public static func any(_ matchers: [ElementMatcher]) -> ElementMatcher {
        return { element in
            for matcher in matchers {
                if await matcher(element) {
                    return true
                }
            }
            return false
        }
    }

    public static func hasRole(_ role: Role) -> ElementMatcher {
        return hasAttribute(.role, equalTo: role)
    }

    public static let always: ElementMatcher = { _ in true }
}

// MARK: - Element Extension

public extension ElementProtocol {
    func search(
        excludeElement: ElementMatcher? = nil,
        skipChildren: ElementMatcher? = nil,
        terminationCondition: ElementMatcher? = nil,
        deadline: Deadline = .never,
        maxDepth: Int = .max,
        timeout: TimeInterval? = 5.0
    ) -> ElementDepthFirstSequence {
        return ElementDepthFirstSequence(
            element: self,
            excludeElement: excludeElement,
            skipChildren: skipChildren,
            terminationCondition: terminationCondition,
            deadline: deadline,
            maxDepth: maxDepth,
            timeout: timeout
        )
    }
    
    func traverse(
        rules: [RuleProtocol],
        excludeMatchers: [ElementMatcher] = [],
        maxDepth: Int = .max,
        findInOrder: Bool = false,
        terminateAfterAnyRule: Bool = false,
        terminateAfterAllRules: Bool = false,
        deadline: Deadline = .never
    ) async throws {
        var matchedRuleIndexes = Set<Int>()
        
        let excludeMatcher: ElementMatcher = { element in
            for matcher in excludeMatchers {
                if await matcher(element) {
                    return true
                }
            }
            return false
        }
        
        let sequence = ElementDepthFirstSequence(
            element: self,
            excludeElement: excludeMatcher,
            deadline: deadline,
            maxDepth: maxDepth
        )
        
        for try await item in sequence {
            let element = item.element
            
            if findInOrder {
                if let firstUnmatchedIndex = (0..<rules.count).first(where: { !matchedRuleIndexes.contains($0) }),
                   await rules[firstUnmatchedIndex].apply(element) {
                    matchedRuleIndexes.insert(firstUnmatchedIndex)
                    if terminateAfterAnyRule || (terminateAfterAllRules && matchedRuleIndexes.count == rules.count) {
                        return
                    }
                }
            } else {
                for (index, rule) in rules.enumerated() {
                    if await rule.apply(element) {
                        if terminateAfterAnyRule {
                            return
                        }
                        if terminateAfterAllRules {
                            matchedRuleIndexes.insert(index)
                            if matchedRuleIndexes.count == rules.count {
                                return
                            }
                        }
                    }
                }
            }
        }
    }

    func findElements(
        matching matcher: @escaping ElementMatcher,
        excludeMatchers: [ElementMatcher] = [],
        maxDepth: Int = .max,
        deadline: Deadline = .never
    ) async throws -> [ElementProtocol] {
        let collector = Collectors.makeElementCollector()
        let rule = Rule(matcher: matcher, collector: collector)
        try await traverse(
            rules: [rule],
            excludeMatchers: excludeMatchers,
            maxDepth: maxDepth,
            deadline: deadline
        )
        return await collector.getItems()
    }

    func findElement(
        matching matcher: @escaping ElementMatcher,
        excludeMatchers: [ElementMatcher] = [],
        maxDepth: Int = .max,
        deadline: Deadline = .never
    ) async throws -> ElementProtocol? {
        let collector = Collectors.makeElementCollector()
        let rule = Rule(matcher: matcher, collector: collector)
        try await traverse(
            rules: [rule],
            excludeMatchers: excludeMatchers,
            maxDepth: maxDepth,
            terminateAfterAnyRule: true,
            deadline: deadline
        )
        return await collector.getFirst()
    }

    func collectElements(
        /// Map a list of matchers to the a list of elements matched by each matcher
        /// An option allows testing each matchers in order only after the previous has matched
        matchers: [ElementMatcher],
        findInOrder: Bool = false,
        excludeMatchers: [ElementMatcher] = [],
        maxDepth: Int = .max,
        deadline: Deadline = .never
    ) async throws -> [ElementProtocol?] {
        // Create the collectors for each matcher index
        var collector: ElementCollector = Collectors.makeElementCollector()

        // Create rules from matchers
        let rules = matchers.enumerated().map { index, matcher in
            Rule(
                matcher: matcher,
                collector: collector
            )
        }
        
        // Use traverse with the rules
        try await traverse(
            rules: rules,
            excludeMatchers: excludeMatchers,
            maxDepth: maxDepth,
            findInOrder: findInOrder,
            terminateAfterAllRules: true,
            deadline: deadline
        )
        
        return await collector.getItems()
    }

    func collectTreeValues(
        matching matcher: @escaping ElementMatcher = Matchers.always,
        excludeMatchers: [ElementMatcher] = [],
        maxDepth: Int = .max,
        deadline: Deadline = .never,
        separator: String = " "
    ) async throws -> String? {
        let collector = Collectors.makeTextCollector()
        let rule = Rule(matcher: matcher, collector: collector)
        try await traverse(
            rules: [rule],
            excludeMatchers: excludeMatchers,
            maxDepth: maxDepth,
            deadline: deadline
        )
        let items = await collector.getItems()
        let result = items.joined(separator: separator)
        return result.isEmpty ? nil : result
    }

    func collectTreeValuesOrDescriptions(
        matching matcher: @escaping ElementMatcher = Matchers.always,
        excludeMatchers: [ElementMatcher] = [],
        maxDepth: Int = .max,
        deadline: Deadline = .never,
        separator: String = " "
    ) async throws -> String? {
        // Using TextCollector directly
        let collector = Collectors.makeValueOrDescriptionCollector()
        let rule = Rule(matcher: matcher, collector: collector)
        try await traverse(
            rules: [rule],
            excludeMatchers: excludeMatchers,
            maxDepth: maxDepth,
            deadline: deadline
        )
        let items = await collector.getItems()
        let result = items.joined(separator: separator)
        return result
    }

    func getFirstChildValue() async throws -> String? {
        guard let children = try getChildren(),
              let firstChild = children.first else {
            return nil
        }
        return try firstChild.getValue()
    }

    func findElementWithClass(
        _ className: String,
        excludeMatchers: [ElementMatcher] = [],
        maxDepth: Int = .max,
        deadline: Deadline = .never
    ) async throws -> ElementProtocol? {
        return try await findElement(
            matching: Matchers.hasClass(className),
            excludeMatchers: excludeMatchers,
            maxDepth: maxDepth,
            deadline: deadline
        )
    }

    func hasClass(_ className: String) async throws -> Bool {
        return await Matchers.hasClass(className)(self)
    }

    func hasClassContaining(_ substring: String) async throws -> Bool {
        return await Matchers.hasClassContaining(substring)(self)
    }
}
