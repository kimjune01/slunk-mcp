@preconcurrency import ApplicationServices
import Foundation

/// Declares the required functionality for any native Swift type that can be cast to a legacy Core Foundation
/// accessibility type.
@Accessibility protocol Legacy where Self: Encodable {
    /// Converts this Swift type to a legacy accessibility type.
    var axValue: CFTypeRef { get }
}

@Accessibility extension Optional {
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

@Accessibility extension Bool {
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

@Accessibility extension Int64 {
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

@Accessibility extension Double {
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

@Accessibility extension String {
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

@Accessibility extension Array {
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

@Accessibility extension Dictionary where Key == String {
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

@Accessibility extension URL {
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

@Accessibility extension AttributedString {
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

@Accessibility extension Range where Bound == Int64 {
    /// Attempts to initialize a native integer range value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let value = value as! AXValue
        var range = CFRangeMake(0, 0)
        guard AXValueGetValue(value, .cfRange, &range) else {
            return nil
        }
        self = Int64(range.location)..<Int64(range.location + range.length)
    }
}

extension Range: Legacy where Bound == Int {
    var axValue: CFTypeRef {
        var range = CFRangeMake(self.lowerBound, self.upperBound - self.lowerBound)
        return AXValueCreate(.cfRange, &range)!
    }
}

@Accessibility extension Point {
    /// Attempts to initialize a native point value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let value = value as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else {
            return nil
        }
        self = Self(point)
    }
}

extension Point: Legacy {
    var axValue: CFTypeRef {
        var point = CGPoint(self)
        return AXValueCreate(.cgPoint, &point)!
    }
}

@Accessibility extension Size {
    /// Attempts to initialize a native size value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let value = value as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else {
            return nil
        }
        self = Self(size)
    }
}

extension Size: Legacy {
    var axValue: CFTypeRef {
        var size = CGSize(self)
        return AXValueCreate(.cgSize, &size)!
    }
}

@Accessibility extension Rect {
    /// Attempts to initialize a native rectangle value from a Core Foundation value.
    init?(axValue value: CFTypeRef) {
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let value = value as! AXValue
        var rect = CGRect.zero
        guard AXValueGetValue(value, .cgRect, &rect) else {
            return nil
        }
        self = Self(rect)
    }
}

extension Rect: Legacy {
    var axValue: CFTypeRef {
        var rect = CGRect(self)
        return AXValueCreate(.cgRect, &rect)!
    }
}

/// Sendable type containing the same information as a ``CGPoint``.
public struct Point: Sendable, Encodable, Equatable {
    /// Horizontal position.
    public let x: Double
    /// Vertical position.
    public let y: Double
    /// Point initialized to the origin.
    public static let zero = Point(x: 0.0, y: 0.0)

    /// Initializes from a Core Graphics point.
    /// - Parameter cgPoint: Core Graphics point.
    public init(_ cgPoint: CGPoint) {
        self.init(x: Double(cgPoint.x), y: Double(cgPoint.y))
    }

    /// Initializes from raw components.
    /// - Parameters:
    ///   - x: Horizontal position.
    ///   - y: Vertical position.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public extension CGPoint {
    /// Initializes from an accessibility point.
    /// - Parameter point: Accessibility point.
    init(_ point: Point) {
        self = Self(x: CGFloat(point.x), y: CGFloat(point.y))
    }
}

/// Sendable type containing the same information as a ``CGSize``.
public struct Size: Sendable, Encodable, Equatable {
    /// Horizontal size.
    public let width: Double
    /// Vertical size.
    public let height: Double
    /// Infinitesimal size.
    public static let zero = Size(width: 0.0, height: 0.0)

    /// Initializes from a Core Graphics size.
    /// - Parameter cgSize: Core Graphics size.
    public init(_ cgSize: CGSize) {
        self.init(width: Double(cgSize.width), height: Double(cgSize.height))
    }

    /// Initializes from raw components.
    /// - Parameters:
    ///   - width: Horizontal size.
    ///   - height: Vertical size.
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public extension CGSize {
    /// Initializes from an accessibility size.
    /// - Parameter size: Accessibility size.
    init(_ size: Size) {
        self = Self(width: CGFloat(size.width), height: CGFloat(size.height))
    }
}

/// Sendable type containing the same information as a ``CGRect``.
public struct Rect: Encodable, Sendable {
    /// Origin of the rectangle.
    public let origin: Point
    /// Dimensions of the rectangle.
    public let size: Size
    /// Infinitesimal rectangle initialized to the origin.
    public static let zero = Self(origin: Point.zero, size: Size.zero)

    /// Initializes from a Core Graphics rectangle.
    /// - Parameter cgRect: Core Graphics rectangle.
    public init(_ cgRect: CGRect) {
        self.init(origin: Point(cgRect.origin), size: Size(cgRect.size))
    }

    /// Initializes from origin and size components.
    /// - Parameters:
    ///   - origin: Rectangle origin.
    ///   - size: Rectangle size.
    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }
}

public extension CGRect {
    /// Initializes from an accessibility rectangle.
    /// - Parameter rect: Accessibility rectangle.
    init(_ rect: Rect) {
        self = Self(origin: CGPoint(rect.origin), size: CGSize(rect.size))
    }
}

/// Converts a supported legacy accessibility value to a native Swift value.
/// - Parameter value: Value to convert.
/// - Returns: Native Swift value.
@Accessibility func swiftConvert(axValue value: CFTypeRef) -> Sendable {
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
    if let range = Range<Int64>(axValue: value) {
        return range
    }
    if let point = Point(axValue: value) {
        return point
    }
    if let size = Size(axValue: value) {
        return size
    }
    if let rect = Rect(axValue: value) {
        return rect
    }
    if let error = AccessError(axValue: value) {
        return error
    }
    if let element = Element(axValue: value) {
        return element
    }
    return Void?.none
}
