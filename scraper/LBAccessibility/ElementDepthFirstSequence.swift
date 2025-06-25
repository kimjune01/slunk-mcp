//
//  ElementDepthFirstSequence.swift
//  observer-lib
//
//  Created by Soroush Khanlou on 1/9/25.
//

import Foundation
import LBMetrics

public struct StackItem: Sendable {
    public let element: ElementProtocol
    public let path: [Int] // Track the index path to this element

    public var pathString: String {
        return "[" + path.map(String.init).joined(separator: "/") + "]"
    }

    public init(element: ElementProtocol, path: [Int]) {
        self.element = element
        self.path = path
    }
}

public struct ElementDepthFirstSequence: AsyncSequence {
    public enum ChildType { case contents, children }
    public typealias ElementMatcher = @Sendable (ElementProtocol) async -> Bool
    
    public typealias Element = StackItem
    
    public static let maxStackSize: Int = 25000
    public static let stackSizeLogIncrement: Int = 1000

    let element: ElementProtocol
    var childType: ChildType
    var excludeElement: ElementMatcher?
    var skipChildren: ElementMatcher?
    var terminationCondition: ElementMatcher?
    var deadline: Deadline
    var maxDepth: Int

    public init(
        element: ElementProtocol,
        childType: ChildType = .children,
        excludeElement: ElementMatcher? = nil,
        skipChildren: ElementMatcher? = nil,
        terminationCondition: ElementMatcher? = nil,
        deadline: Deadline = .never,
        maxDepth: Int = .max,
        timeout: TimeInterval? = 5.0
    ) {
        self.element = element
        self.childType = childType
        self.excludeElement = excludeElement
        self.skipChildren = skipChildren
        self.terminationCondition = terminationCondition
        self.maxDepth = maxDepth

        if timeout == 0 {
            self.deadline = deadline
        } else if let timeout {
            let timeoutDeadline = Deadline.fromNow(duration: timeout)
            if deadline == .never {
                self.deadline = timeoutDeadline
            } else {
                self.deadline = deadline.endDate < timeoutDeadline.endDate ? deadline : timeoutDeadline
            }
        } else {
            self.deadline = deadline
        }
    }

    public func makeAsyncIterator() -> ElementDepthFirstIterator {
        ElementDepthFirstIterator(
            rootElement: element,
            childType: childType,
            excludeElement: excludeElement,
            skipChildren: skipChildren,
            terminationCondition: terminationCondition,
            deadline: deadline,
            maxDepth: maxDepth
        )
    }

    public struct ElementDepthFirstIterator: AsyncIteratorProtocol {
        var stack: [StackItem]
        var excludeElement: ElementMatcher?
        var skipChildren: ElementMatcher?
        var terminationCondition: ElementMatcher?
        var deadline: Deadline
        var maxDepth: Int
        var lastLoggedSize = 0
        
        init(
            rootElement: ElementProtocol,
            childType: ChildType,
            excludeElement: ElementMatcher? = nil,
            skipChildren: ElementMatcher? = nil,
            terminationCondition: ElementMatcher? = nil,
            deadline: Deadline,
            maxDepth: Int
        ) {
            self.stack = [StackItem(element: rootElement, path: [])]
            self.excludeElement = excludeElement
            self.skipChildren = skipChildren
            self.terminationCondition = terminationCondition
            self.deadline = deadline
            self.maxDepth = maxDepth
        }

        public mutating func next() async -> StackItem? {
            while !stack.isEmpty {
                if deadline.hasPassed {
                    stack = []
                    return nil
                }
                
                if stack.count > ElementDepthFirstSequence.maxStackSize {
                    Log.error("ElementDepthFirstIterator: Stack size exceeded maximum (\(ElementDepthFirstSequence.maxStackSize))")
                    stack = []
                    return nil
                }
                
                let currentSize = stack.count
                let incrementThreshold = currentSize / ElementDepthFirstSequence.stackSizeLogIncrement
                if incrementThreshold > lastLoggedSize / ElementDepthFirstSequence.stackSizeLogIncrement {
                    Log.info("ElementDepthFirstIterator: Stack size: \(incrementThreshold * ElementDepthFirstSequence.stackSizeLogIncrement)", category: .controlFlow)
                    lastLoggedSize = currentSize
                }
                
                let currentItem = stack.removeLast()
                
                if let terminationCondition = terminationCondition,
                await terminationCondition(currentItem.element) {
                    stack = []
                    return currentItem
                } else if let excludeElement,
                          await excludeElement(currentItem.element) {
                    continue
                } else if let skipChildren,
                          await skipChildren(currentItem.element) {
                    return currentItem
                }
                
                if currentItem.path.count < maxDepth {
                    if let children = try? await currentItem.element.getChildren() {
                        for (index, child) in children.enumerated().reversed() {
                            let newPath = currentItem.path + [index]
                            stack.append(StackItem(element: child, path: newPath))
                        }
                    }
                }

                return currentItem
            }
            return nil
        }
    }
}

public extension AsyncSequence {
    func collect() async throws -> [Element] {
        try await reduce(into: [Element]()) { $0.append($1) }
    }
}
