@preconcurrency import ApplicationServices

/// Parameterized attribute.
public struct ParameterizedAttribute: Identifier {
    public let rawValue: String

    // Text attributes.
    public static let lineForIndex = Self(rawValue: kAXLineForIndexParameterizedAttribute)
    public static let rangeForLine = Self(rawValue: kAXRangeForLineParameterizedAttribute)
    public static let stringForRange = Self(rawValue: kAXStringForRangeParameterizedAttribute)
    public static let rangeForPosition = Self(rawValue: kAXRangeForPositionParameterizedAttribute)
    public static let rangeForIndex = Self(rawValue: kAXRangeForIndexParameterizedAttribute)
    public static let boundsForRange = Self(rawValue: kAXBoundsForRangeParameterizedAttribute)
    public static let rtfForRange = Self(rawValue: kAXRTFForRangeParameterizedAttribute)
    public static let attributedStringForRange = Self(rawValue: kAXAttributedStringForRangeParameterizedAttribute)
    public static let styleRangeForIndex = Self(rawValue: kAXStyleRangeForIndexParameterizedAttribute)

    // Table cell attributes.
    public static let cellForColumnAndRow = Self(rawValue: kAXCellForColumnAndRowParameterizedAttribute)

    // Layout attributes.
    public static let layoutPointForScreenPoint = Self(rawValue: kAXLayoutPointForScreenPointParameterizedAttribute)
    public static let layoutSizeForScreenSize = Self(rawValue: kAXLayoutSizeForScreenSizeParameterizedAttribute)
    public static let screenPointForLayoutPoint = Self(rawValue: kAXScreenPointForLayoutPointParameterizedAttribute)
    public static let screenSizeForLayoutSize = Self(rawValue: kAXScreenSizeForLayoutSizeParameterizedAttribute)
}
