import CryptoKit
import Foundation

// Protocol for objects that can be deduplicated using hash values
public protocol DeduplicateHashable {
    var hashValueForDeduplication: Int { get }
}

extension String: DeduplicateHashable {
    public var hashValueForDeduplication: Int {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)

        // Convert the first 8 bytes of the hash to an Int
        let hashInt = hash.prefix(8).reduce(0) { ($0 << 8) | Int($1) }
        return hashInt
    }

    public func containsIgnoringCase(_ other: String) -> Bool {
        return self.range(of: other, options: .caseInsensitive) != nil
    }
}