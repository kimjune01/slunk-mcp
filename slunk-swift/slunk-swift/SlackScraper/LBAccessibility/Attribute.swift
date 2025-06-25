@preconcurrency import ApplicationServices

/// Element attribute.
public struct Attribute: Identifier {
    public let rawValue: String

    // Informational attributes.
    public static let role = Self(rawValue: kAXRoleAttribute)
    public static let subrole = Self(rawValue: kAXSubroleAttribute)
    public static let roleDescription = Self(rawValue: kAXRoleDescriptionAttribute)
    public static let title = Self(rawValue: kAXTitleAttribute)
    public static let description = Self(rawValue: kAXDescriptionAttribute)
    public static let help = Self(rawValue: kAXHelpAttribute)
    public static let identifier = Self(rawValue: kAXIdentifierAttribute)

    // Web/DOM-specific attributes
    public static let domIdentifier = Self(rawValue: "AXDOMIdentifier")
    public static let domClassList = Self(rawValue: "AXDOMClassList")

    // Hierarchical relationship attributes.
    public static let parentElement = Self(rawValue: kAXParentAttribute)
    public static let childElements = Self(rawValue: kAXChildrenAttribute)
    public static let childElementsInNavigationOrder = Self(rawValue: "AXChildrenInNavigationOrder")
    public static let selectedChildrenElements = Self(rawValue: kAXSelectedChildrenAttribute)
    public static let visibleChildrenElements = Self(rawValue: kAXVisibleChildrenAttribute)
    public static let windowElement = Self(rawValue: kAXWindowAttribute)
    public static let topLevelElement = Self(rawValue: kAXTopLevelUIElementAttribute)
    public static let titleElement = Self(rawValue: kAXTitleUIElementAttribute)
    public static let servesAsTitleForElement = Self(rawValue: "AXServesAsTitleForUIElement")
    public static let linkedElements = Self(rawValue: kAXLinkedUIElementsAttribute)
    public static let sharedFocusElements = Self(rawValue: kAXSharedFocusElementsAttribute)
    public static let focusableAncestor = Self(rawValue: "AXFocusableAncestor")

    // Visual state attributes.
    public static let isEnabled = Self(rawValue: kAXEnabledAttribute)
    public static let isFocused = Self(rawValue: kAXFocusedAttribute)
    public static let position = Self(rawValue: kAXPositionAttribute)
    public static let size = Self(rawValue: kAXSizeAttribute)

    // Value attributes.
    public static let value = Self(rawValue: kAXValueAttribute)
    public static let valueDescription = Self(rawValue: kAXValueDescriptionAttribute)
    public static let minValue = Self(rawValue: kAXMinValueAttribute)
    public static let maxValue = Self(rawValue: kAXMaxValueAttribute)
    public static let valueIncrement = Self(rawValue: kAXValueIncrementAttribute)
    public static let valueWraps = Self(rawValue: kAXValueWrapsAttribute)
    public static let allowedValues = Self(rawValue: kAXAllowedValuesAttribute)
    public static let placeholderValue = Self(rawValue: kAXPlaceholderValueAttribute)

    // Text-specific attributes.
    public static let selectedText = Self(rawValue: kAXSelectedTextAttribute)
    public static let selectedTextRange = Self(rawValue: kAXSelectedTextRangeAttribute)
    public static let selectedTextRanges = Self(rawValue: kAXSelectedTextRangesAttribute)
    public static let visibleTextRange = Self(rawValue: "AXVisibleTextRange")
    public static let numberOfCharacters = Self(rawValue: "AXNumberOfCharacters")
    public static let sharedTextElements = Self(rawValue: kAXSharedTextUIElementsAttribute)
    public static let sharedCharacterRange = Self(rawValue: kAXSharedCharacterRangeAttribute)
    public static let insertionPointLineNumber = Self(rawValue: kAXInsertionPointLineNumberAttribute)

    // Top-level element attributes.
    public static let isMain = Self(rawValue: kAXMainAttribute)
    public static let isMinimized = Self(rawValue: kAXMinimizedAttribute)
    public static let closeButton = Self(rawValue: kAXCloseButtonAttribute)
    public static let zoomButton = Self(rawValue: kAXZoomButtonAttribute)
    public static let minimizeButton = Self(rawValue: kAXMinimizeButtonAttribute)
    public static let toolbar = Self(rawValue: kAXToolbarButtonAttribute)
    public static let fullScreenButton = Self(rawValue: kAXFullScreenButtonAttribute)
    public static let proxy = Self(rawValue: kAXProxyAttribute)
    public static let growArea = Self(rawValue: kAXGrowAreaAttribute)
    public static let isModal = Self(rawValue: kAXModalAttribute)
    public static let defaultButton = Self(rawValue: kAXDefaultButtonAttribute)
    public static let cancelButton = Self(rawValue: kAXCancelButtonAttribute)

    // Menu-specific attributes.
    public static let menuItemCmdChar = Self(rawValue: kAXMenuItemCmdCharAttribute)
    public static let menuItemCmdVirtualKey = Self(rawValue: kAXMenuItemCmdVirtualKeyAttribute)
    public static let menuItemCmdGlyph = Self(rawValue: kAXMenuItemCmdGlyphAttribute)
    public static let menuItemCmdModifiers = Self(rawValue: kAXMenuItemCmdModifiersAttribute)
    public static let menuItemMarkChar = Self(rawValue: kAXMenuItemMarkCharAttribute)
    public static let menuItemPrimaryElement = Self(rawValue: kAXMenuItemPrimaryUIElementAttribute)

    // Attributes specific to application elements.
    public static let menuBar = Self(rawValue: kAXMenuBarAttribute)
    public static let windows = Self(rawValue: kAXWindowsAttribute)
    public static let frontmostWindow = Self(rawValue: kAXFrontmostAttribute)
    public static let hidden = Self(rawValue: kAXHiddenAttribute)
    public static let mainWindow = Self(rawValue: kAXMainWindowAttribute)
    public static let focusedWindow = Self(rawValue: kAXFocusedWindowAttribute)
    public static let focusedElement = Self(rawValue: kAXFocusedUIElementAttribute)
    public static let extrasMenuBar = Self(rawValue: kAXExtrasMenuBarAttribute)

    // Table attributes.
    public static let rows = Self(rawValue: kAXRowsAttribute)
    public static let visibleRows = Self(rawValue: kAXVisibleRowsAttribute)
    public static let selectedRows = Self(rawValue: kAXSelectedRowsAttribute)
    public static let columns = Self(rawValue: kAXColumnsAttribute)
    public static let visibleColumns = Self(rawValue: kAXVisibleColumnsAttribute)
    public static let selectedColumns = Self(rawValue: kAXSelectedColumnsAttribute)
    public static let selectedCells = Self(rawValue: kAXSelectedCellsAttribute)
    public static let sortDirection = Self(rawValue: kAXSortDirectionAttribute)
    public static let columnHeaderElements = Self(rawValue: kAXColumnHeaderUIElementsAttribute)
    public static let index = Self(rawValue: kAXIndexAttribute)
    public static let disclosing = Self(rawValue: kAXDisclosingAttribute)
    public static let disclosedRows = Self(rawValue: kAXDisclosedRowsAttribute)
    public static let disclosedByRow = Self(rawValue: kAXDisclosedByRowAttribute)

    // Role-specific attributes.
    public static let horizontalScrollBar = Self(rawValue: kAXHorizontalScrollBarAttribute)
    public static let verticalScrollBar = Self(rawValue: kAXVerticalScrollBarAttribute)
    public static let orientation = Self(rawValue: kAXOrientationAttribute)
    public static let header = Self(rawValue: kAXHeaderAttribute)
    public static let edited = Self(rawValue: kAXEditedAttribute)
    public static let tabs = Self(rawValue: kAXTabsAttribute)
    public static let overflowButton = Self(rawValue: kAXOverflowButtonAttribute)
    public static let fileName = Self(rawValue: kAXFilenameAttribute)
    public static let expanded = Self(rawValue: kAXExpandedAttribute)
    public static let selected = Self(rawValue: kAXSelectedAttribute)
    public static let splitters = Self(rawValue: kAXSplittersAttribute)
    public static let contents = Self(rawValue: kAXContentsAttribute)
    public static let nextContents = Self(rawValue: kAXNextContentsAttribute)
    public static let previousContents = Self(rawValue: kAXPreviousContentsAttribute)
    public static let document = Self(rawValue: kAXDocumentAttribute)
    public static let incrementor = Self(rawValue: kAXIncrementorAttribute)
    public static let decrementButton = Self(rawValue: kAXDecrementButtonAttribute)
    public static let incrementButton = Self(rawValue: kAXIncrementButtonAttribute)
    public static let columnTitle = Self(rawValue: kAXColumnTitleAttribute)
    public static let url = Self(rawValue: kAXURLAttribute)
    public static let labelValue = Self(rawValue: kAXLabelValueAttribute)
    public static let shownMenuElement = Self(rawValue: kAXShownMenuUIElementAttribute)
    public static let focusedApplication = Self(rawValue: kAXFocusedApplicationAttribute)
    public static let elementBusy = Self(rawValue: kAXElementBusyAttribute)
    public static let alternateUIVisible = Self(rawValue: kAXAlternateUIVisibleAttribute)
    public static let isApplicationRunning = Self(rawValue: kAXIsApplicationRunningAttribute)
    public static let searchButton = Self(rawValue: kAXSearchButtonAttribute)
    public static let clearButton = Self(rawValue: kAXClearButtonAttribute)

    // Level indicator attributes.
    public static let warningValue = Self(rawValue: kAXWarningValueAttribute)
    public static let criticalValue = Self(rawValue: kAXCriticalValueAttribute)
}