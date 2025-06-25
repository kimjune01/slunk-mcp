@preconcurrency import ApplicationServices
import Foundation

/// Declares the required functionality for any native Swift type that can be cast to a legacy Core Foundation
/// accessibility type.
protocol Legacy where Self: Encodable {
    /// Converts this Swift type to a legacy accessibility type.
    var axValue: CFTypeRef { get }
}

extension Optional {
    /// Attempts to initialize a native Optional value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        self = swiftConvert(axValue: value) as? Wrapped
    }
}

extension Optional: Legacy where Wrapped: Legacy {
    var axValue: CFTypeRef {
        guard let value = self else {
            return kCFNull
        }
        return value.axValue
    }
}

extension Bool {
    /// Attempts to initialize a native boolean value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFBooleanGetTypeID() else {
            return nil
        }
        let boolean = value as! CFBoolean
        self = CFBooleanGetValue(boolean)
    }
}

extension Bool: Legacy {
    var axValue: CFTypeRef {
        return self ? kCFBooleanTrue : kCFBooleanFalse
    }
}

extension Int64 {
    /// Attempts to initialize a native integer value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFNumberGetTypeID() else {
            return nil
        }
        let number = value as! CFNumber
        var integer = Int64(0)
        guard CFNumberGetValue(number, .sInt64Type, &integer) else {
            return nil
        }
        guard let integer = Self(exactly: integer) else {
            return nil
        }
        self = integer
    }
}

extension Int64: Legacy {
    var axValue: CFTypeRef {
        var integer = self
        return CFNumberCreate(nil, .sInt64Type, &integer)
    }
}

extension Double {
    /// Attempts to initialize a native floating point value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFNumberGetTypeID() else {
            return nil
        }
        let number = value as! CFNumber
        var float = Double(0.0)
        guard CFNumberGetValue(number, .doubleType, &float) else {
            return nil
        }
        guard let float = Self(exactly: float) else {
            return nil
        }
        self = float
    }
}

extension Double: Legacy {
    var axValue: CFTypeRef {
        var float = self
        return CFNumberCreate(nil, .doubleType, &float)
    }
}

extension String {
    /// Attempts to initialize a native string value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFStringGetTypeID() else {
            return nil
        }
        self = value as! CFString as Self
    }
}

extension String: Legacy {
    var axValue: CFTypeRef {
        return self as CFString
    }
}

extension Array {
    /// Attempts to initialize a native array value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFArrayGetTypeID() else {
            return nil
        }
        let array = value as! CFArray as [CFTypeRef]
        self.init(array.lazy.compactMap({ swiftConvert(axValue: $0) as? Element }))
    }
}

extension Array: Legacy where Element: Legacy {
    var axValue: CFTypeRef {
        return self.map({ $0.axValue }) as CFArray
    }
}

extension Dictionary where Key == String {
    /// Attempts to initialize a native dictionary value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFDictionaryGetTypeID() else {
            return nil
        }
        let dictionary = value as! CFDictionary as NSDictionary
        self.init(uniqueKeysWithValues: dictionary.lazy.compactMap({ (entry: NSDictionary.Element) -> (
            key: String,
            value: Value
        )? in (
                key: String(axValue: entry.key as CFTypeRef),
                value: swiftConvert(axValue: entry.value as CFTypeRef)
            ) as? (key: String, value: Value) }))
    }
}

extension Dictionary: Legacy where Key == String, Value: Legacy {
    var axValue: CFTypeRef {
        return [CFString: CFTypeRef](uniqueKeysWithValues: self.map({ (
            key: $0.0.axValue as! CFString,
            value: $0.1.axValue
        ) })) as CFDictionary
    }
}

extension URL {
    /// Attempts to initialize a native URL value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFURLGetTypeID() else {
            return nil
        }
        self = value as! CFURL as URL
    }
}

extension URL: Legacy {
    var axValue: CFTypeRef {
        return self as CFURL
    }
}

extension AttributedString {
    /// Attempts to initialize a native attributed string value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFAttributedStringGetTypeID() else {
            return nil
        }
        let attributedString = value as! CFAttributedString as NSAttributedString
        self = AttributedString(attributedString)
    }
}

extension AttributedString: Legacy {
    var axValue: CFTypeRef {
        return NSAttributedString(self) as CFAttributedString
    }
}

/// Converts a supported legacy accessibility value to a native Swift value.
/// - Parameter value: Value to convert.
/// - Returns: Native Swift value.
func swiftConvert(axValue value: CFTypeRef) -> Sendable {
    if let boolean = Bool(axValue: value) {
        return boolean
    }
    if let integer = Int64(axValue: value) {
        return integer
    }
    if let float = Double(axValue: value) {
        return float
    }
    if let string = String(axValue: value) {
        return string
    }
    if let array = [Sendable](axValue: value) {
        return array
    }
    if let dictionary = [String: Sendable](axValue: value) {
        return dictionary
    }
    if let url = URL(axValue: value) {
        return url
    }
    if let attributedString = AttributedString(axValue: value) {
        return attributedString
    }
    if let element = Element(axValue: value) {
        return element
    }
    return Void?.none
}