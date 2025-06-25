@preconcurrency import ApplicationServices

/// Element subrole.
public struct Subrole: Identifier {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let closeButton = Self(rawValue: kAXCloseButtonSubrole)
    public static let minimizeButton = Self(rawValue: kAXMinimizeButtonSubrole)
    public static let zoomButton = Self(rawValue: kAXZoomButtonSubrole)
    public static let toolBarButton = Self(rawValue: kAXToolbarButtonSubrole)
    public static let fullScreenButton = Self(rawValue: kAXFullScreenButtonSubrole)
    public static let secureTextField = Self(rawValue: kAXSecureTextFieldSubrole)
    public static let tableRow = Self(rawValue: kAXTableRowSubrole)
    public static let outlineRow = Self(rawValue: kAXOutlineRowSubrole)
    public static let unknown = Self(rawValue: kAXUnknownSubrole)
    public static let standardWindow = Self(rawValue: kAXStandardWindowSubrole)
    public static let dialogWindow = Self(rawValue: kAXDialogSubrole)
    public static let systemDialogWindow = Self(rawValue: kAXSystemDialogSubrole)
    public static let floatingWindow = Self(rawValue: kAXFloatingWindowSubrole)
    public static let systemFloatingWindow = Self(rawValue: kAXSystemFloatingWindowSubrole)
    public static let decorative = Self(rawValue: kAXDecorativeSubrole)
    public static let incrementArrow = Self(rawValue: kAXIncrementArrowSubrole)
    public static let decrementArrow = Self(rawValue: kAXDecrementArrowSubrole)
    public static let incrementPage = Self(rawValue: kAXIncrementPageSubrole)
    public static let decrementPage = Self(rawValue: kAXDecrementPageSubrole)
    public static let sortButton = Self(rawValue: kAXSortButtonSubrole)
    public static let searchField = Self(rawValue: kAXSearchFieldSubrole)
    public static let timeline = Self(rawValue: kAXTimelineSubrole)
    public static let ratingIndicator = Self(rawValue: kAXRatingIndicatorSubrole)
    public static let contentList = Self(rawValue: kAXContentListSubrole)
    public static let descriptionList = Self(rawValue: kAXDescriptionListSubrole)
    public static let toggle = Self(rawValue: kAXToggleSubrole)
    public static let selector = Self(rawValue: kAXSwitchSubrole)
    public static let applicationDockItem = Self(rawValue: kAXApplicationDockItemSubrole)
    public static let documentDockItem = Self(rawValue: kAXDocumentDockItemSubrole)
    public static let folderDockItem = Self(rawValue: kAXFolderDockItemSubrole)
    public static let minimizedWindowDockItem = Self(rawValue: kAXMinimizedWindowDockItemSubrole)
    public static let urlDockItem = Self(rawValue: kAXURLDockItemSubrole)
    public static let extraDockItem = Self(rawValue: kAXDockExtraDockItemSubrole)
    public static let trashDockItem = Self(rawValue: kAXTrashDockItemSubrole)
    public static let separatorDockItem = Self(rawValue: kAXSeparatorDockItemSubrole)
    public static let processSwitcherList = Self(rawValue: kAXProcessSwitcherListSubrole)
    public static let landmarkMain = Self(rawValue: "AXLandmarkMain")
    public static let landmarkRegion = Self(rawValue: "AXLandmarkRegion")
}