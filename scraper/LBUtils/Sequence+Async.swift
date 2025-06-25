//
//  Sequence+Async.swift
//  observer-lib
//
//  Created by Anton Holub on 25.03.2025.
//

import Foundation

public extension Sequence {
    /// Returns the first element of the sequence that satisfies the given asynchronous predicate.
    /// - Parameter predicate: An asynchronous closure that takes an element of the sequence as its argument and returns
    /// a Boolean value indicating whether the element is a match.
    /// - Returns: The first element of the sequence that satisfies `predicate`, or `nil` if there is no element that
    /// satisfies `predicate`.
    func asyncFirst(where predicate: @escaping (Element) async throws -> Bool) async rethrows -> Element? {
        for element in self {
            if try await predicate(element) {
                return element
            }
        }

        return nil
    }
}
