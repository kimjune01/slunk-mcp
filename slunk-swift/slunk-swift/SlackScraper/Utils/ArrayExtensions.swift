import Foundation

public extension Array {
    mutating func append(_ element: Element, maxCount: Int) {
        append(element)
        if count > maxCount {
            let countToRemove = count - maxCount
            removeFirst(countToRemove)
        }
    }
}