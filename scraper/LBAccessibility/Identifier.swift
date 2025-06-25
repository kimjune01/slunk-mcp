/// Standard functionality provided by identifier types.
public protocol Identifier: CustomStringConvertible, Encodable, Hashable, Sendable {
    /// Type of the identifier's raw value.
    associatedtype RawValue: CustomStringConvertible & Encodable & Hashable & Sendable

    /// Raw value of this identifier.
    var rawValue: Self.RawValue { get }
}

public extension Identifier {
    var description: String { String(describing: rawValue) }

    func encode(to encoder: any Encoder) throws {
        try rawValue.encode(to: encoder)
    }

    func hash(into hasher: inout Hasher) {
        rawValue.hash(into: &hasher)
    }

    static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}
