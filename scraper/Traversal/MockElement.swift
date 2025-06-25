//
//  MockElement.swift
//  observer-lib
//
//  Created by Soroush Khanlou on 12/5/24.
//

import Foundation
import LBAccessibility

// Make MockElement public so it can be used by the json-dumper tool
public struct MockElement: ElementProtocol {
    private let json: DumpResult

    public init(json: DumpResult) {
        self.json = json
    }

    public func getValue() throws -> String? {
        nil
    }

    public func getAttributeValue(_ attribute: Attribute) throws -> (any Sendable)? {
        try getAttributeValue(attribute.rawValue)
    }

    public func getChildren() throws -> [ElementProtocol]? {
        let result = json.attributes[Attribute.childElements.rawValue]
        if case let .elements(children) = result {
            return children.map({ MockElement(json: $0) })
        } else {
            return nil
        }
    }

    public func getAttributeValueCount(_ attribute: Attribute) throws -> Int? {
        0
    }

    public func getLabel() throws -> String? {
        json.attributes[Attribute.labelValue.rawValue]?.value as? String
    }

    public func getContents() throws -> [any ElementProtocol]? {
        switch json.attributes[Attribute.contents.rawValue] {
        case let .element(dump)?:
            [MockElement(json: dump)]
        case let .elements(dumps)?:
            dumps.map({ MockElement(json: $0) })
        default:
            nil
        }
    }

    public func getAttributeValue(_ attribute: String) throws -> (any Sendable)? {
        let output = json.attributes[attribute]?.value
        if attribute == Attribute.role.rawValue, let output = output as? String {
            return Role(rawValue: output)
        }
        if attribute == Attribute.subrole.rawValue, let output = output as? String {
            return Subrole(rawValue: output)
        }
        // Handle DOM class list special case - they are stored as a space-separated string in JSON,
        // but parsers expect an array of strings
        if attribute == Attribute.domClassList.rawValue, let output = output as? String {
            // Split by spaces and filter out empty strings
            return output.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        }
        return output
    }

    public func listAttributes() throws -> [String] {
        Array(json.attributes.keys)
    }

    public func listActions() throws -> [String] {
        []
    }

    public func listParameterizedAttributes() throws -> [String] {
        []
    }

    public func getParent(atLevel level: Int) throws -> ElementProtocol? {
        return nil
    }
}

public struct FixtureNotFound: Error {
    public init() {}
}
