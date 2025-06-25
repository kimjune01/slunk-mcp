//
//  JSONDump.swift
//  observer-lib
//
//  Created by Soroush Khanlou on 12/2/24.
//

import ApplicationServices
import Foundation

public struct DumpResult: Codable, Equatable, Sendable {
    struct CodablePoint: Codable {
        let x: Double, y: Double
    }

    struct CodableSize: Codable {
        let width: Double, height: Double
    }

    struct CodableDouble: Codable {
        let double: Double
    }

    public enum Value: Codable, Equatable, Sendable {
        case string(String)
        case point(Point)
        case size(Size)
        case double(Double)
        case other(any Sendable)
        case element(DumpResult)
        case elements([DumpResult])
        case null

        public static func ==(lhs: Value, rhs: Value) -> Bool {
            switch (lhs, rhs) {
            case (.string(let l), .string(let r)): return l == r
            case (.point(let l), .point(let r)): return l == r
            case (.size(let l), .size(let r)): return l == r
            case (.double(let l), .double(let r)): return l == r
            case (.other(let l), .other(let r)): return String(describing: l) == String(describing: r)
            case (.element(let l), .element(let r)): return l == r
            case (.elements(let l), .elements(let r)): return l == r
            case (.null, .null): return true
            default: return false
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            // decode double, point, and size
            if let string = try? container.decode(String.self) {
                self = .string(string)
            } else if let dump = try? container.decode(DumpResult.self) {
                self = .element(dump)
            } else if let dumpArray = try? container.decode([DumpResult].self) {
                self = .elements(dumpArray)
            } else if let point = try? container.decode(CodablePoint.self) {
                self = .point(.init(x: point.x, y: point.y))
            } else if let size = try? container.decode(CodableSize.self) {
                self = .size(.init(width: size.width, height: size.height))
            } else if let double = try? container.decode(CodableDouble.self) {
                self = .double(double.double)
            } else {
                self = .null
            }
        }

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .string(let value):
                try value.encode(to: encoder)
            case let .element(value):
                try value.encode(to: encoder)
            case let .elements(value):
                try value.encode(to: encoder)
            case let .point(point):
                try Point(x: point.x, y: point.y).encode(to: encoder)
            case let .size(size):
                try Size(width: size.width, height: size.height).encode(to: encoder)
            case let .double(double):
                try CodableDouble(double: double).encode(to: encoder)
            default:
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            }
        }

        public var value: Sendable? {
            switch self {
            case .string(let string):
                return string
            case .other(let sendable):
                return sendable
            case .element(let dumpResult):
                return dumpResult
            case .elements(let array):
                return array
            case .null:
                return nil
            case let .point(point):
                return point
            case let .size(size):
                return size
            case let .double(double):
                return double
            }
        }
    }

    public var attributes = [String: Value]()
    public var parameterizedAttributes = [String]()
}

private let basicAttributes = [
    Attribute.role.rawValue,
    Attribute.roleDescription.rawValue,
    Attribute.subrole.rawValue,
    Attribute.identifier.rawValue,
    Attribute.title.rawValue,
    Attribute.value.rawValue,
    Attribute.labelValue.rawValue,
    Attribute.description.rawValue,
    Attribute.childElements.rawValue,
    Attribute.position.rawValue,
    Attribute.size.rawValue,
    Attribute.domIdentifier.rawValue,
    Attribute.domClassList.rawValue,
]

public extension Element {
    func dumpJSON() -> DumpResult {
        return dumpJSONWithAttributeSet(basicAttributes)
    }

    // Full JSON dump with all attributes needed for Signal and Messenger parsing
    func dumpFullJSON() -> DumpResult {
        return dumpJSONWithAttributeSet(basicAttributes)
    }

    // Helper method to dump JSON with a specified set of attributes
    private func dumpJSONWithAttributeSet(_ attributeSet: [String]) -> DumpResult {
        var root = DumpResult()
        do {
            let attributeNames = try listAttributes()
            for attributeName in attributeNames {
                guard attributeSet.contains(attributeName) else {
                    continue
                }
                guard let value = try getAttributeValue(attributeName) else {
                    continue
                }

                let wrappedValue: DumpResult.Value = if let string = value as? String {
                    .string(string)
                } else if let element = value as? Self {
                    .element(element.dumpJSONWithAttributeSet(attributeSet))
                } else if let elements = value as? [Self] {
                    .elements(elements.map({ $0.dumpJSONWithAttributeSet(attributeSet) }))
                } else if let point = value as? Point {
                    .point(point)
                } else if let size = value as? Size {
                    .size(size)
                } else if let double = value as? Double {
                    .double(double)
                } else {
                    .other(value)
                }
                root.attributes[attributeName] = wrappedValue
            }

            root.parameterizedAttributes = try listParameterizedAttributes()
        } catch {
            print("error: \(error)")
        }
        return root
    }
}
