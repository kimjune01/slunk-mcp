//
//  String+.swift
//  observer-lib
//
//  Created by June Kim on 2024-12-06.
//
import CryptoKit
import Foundation
import LBDataModels

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
