//
//  ElementDescription.swift
//  observer-lib
//
//  Created by Soroush Khanlou on 11/23/24.
//

import Foundation
import LBMetrics

extension ElementProtocol {
    /// Generates a description of the accessibility hierarchy with timeout handling
    /// - Parameters:
    ///   - deadline: Time at which to abort traversal
    ///   - useContents: Whether to use contents instead of children
    ///   - initialPath: Initial path components (e.g., [pid, windowIndex])
    ///   - maxDepth: Maximum depth to traverse in the hierarchy
    ///   - timeout: Optional timeout in seconds, defaults to 5.0s
    /// - Returns: String description of the hierarchy
    public func elementDescription(
        deadline: Deadline = .never,
        useContents: Bool = false,
        initialPath: [Int] = [],
        maxDepth: Int = .max,
        timeout: TimeInterval? = 5.0
    ) async throws -> String {
        var result = ""
        var lastValue = ""
        var lastProperties = ""

        let childType: ElementDepthFirstSequence.ChildType = useContents ? .contents : .children
        let sequence = ElementDepthFirstSequence(
            element: self,
            childType: childType,
            deadline: deadline,
            maxDepth: maxDepth,
            timeout: timeout
        )

        do {
            for try await item in sequence {
                let current = item.path.isEmpty && !initialPath.isEmpty
                    ? StackItem(element: item.element, path: initialPath)
                    : item

                let padding = String(repeating: " ", count: current.path.count)
                var properties = ""

                if let label = try? current.element.getLabel() {
                    properties += label.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                }

                if let value = try? current.element.getValue() {
                    if !properties.isEmpty {
                        properties += " "
                    }
                    let trimmedValue = stripRepeatedLines(
                        from: value
                            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    )
                    if !trimmedValue.isEmpty, trimmedValue != lastValue {
                        properties += trimmedValue
                    }
                    lastValue = trimmedValue
                }

                if !properties.isEmpty, properties != lastProperties {
                    result += (!result.isEmpty ? "\n" : "") + padding + properties
                }
                lastProperties = properties

                try Task.checkCancellation()
            }
        } catch is CancellationError {
            if result.isEmpty {
                throw AccessError.timeout
            }
            Log.info("TIMEOUT during element description traversal", category: .controlFlow)
        } catch {
            throw error
        }

        result = stripRepeatedLines(from: result)
        return result.replacingOccurrences(of: "[\n]+", with: "\n", options: .regularExpression, range: nil)
    }

    private func stripRepeatedLines(from description: String) -> String {
        let lines = description.components(separatedBy: .newlines)
        var result: [String] = []
        var previousLine: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed != previousLine {
                result.append(line)
                previousLine = trimmed
            }
        }

        return result.joined(separator: "\n")
    }
}
