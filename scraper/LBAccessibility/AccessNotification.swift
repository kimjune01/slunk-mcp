@preconcurrency import ApplicationServices

/// Event notification.
public struct AccessNotification: Identifier {
    public let rawValue: String

    // Keyboard focus events.
    public static let windowDidGetFocus = Self(rawValue: kAXFocusedWindowChangedNotification)
    public static let elementDidGetFocus = Self(rawValue: kAXFocusedUIElementChangedNotification)

    // Application events.
    public static let applicationDidBecomeActive = Self(rawValue: kAXApplicationActivatedNotification)
    public static let applicationDidBecomeInactive = Self(rawValue: kAXApplicationDeactivatedNotification)
    public static let applicationDidHide = Self(rawValue: kAXApplicationHiddenNotification)
    public static let applicationDidShow = Self(rawValue: kAXApplicationShownNotification)

    // Top-level element events.
    public static let windowDidAppear = Self(rawValue: kAXWindowCreatedNotification)
    public static let windowDidMove = Self(rawValue: kAXWindowMovedNotification)
    public static let windowDidResize = Self(rawValue: kAXWindowResizedNotification)
    public static let windowDidMinimize = Self(rawValue: kAXWindowMiniaturizedNotification)
    public static let windowDidRestore = Self(rawValue: kAXWindowDeminiaturizedNotification)
    public static let drawerDidSpawn = Self(rawValue: kAXDrawerCreatedNotification)
    public static let sheetDidSpawn = Self(rawValue: kAXSheetCreatedNotification)
    public static let helpTagDidSpawn = Self(rawValue: kAXHelpTagCreatedNotification)

    // Menu events.
    public static let menuDidOpen = Self(rawValue: kAXMenuOpenedNotification)
    public static let menuDidClose = Self(rawValue: kAXMenuClosedNotification)
    public static let menuDidSelectItem = Self(rawValue: kAXMenuItemSelectedNotification)

    // Table and outline events.
    public static let rowCountDidUpdate = Self(rawValue: kAXRowCountChangedNotification)
    public static let rowDidExpand = Self(rawValue: kAXRowExpandedNotification)
    public static let rowDidCollapse = Self(rawValue: kAXRowCollapsedNotification)
    public static let cellSelectionDidUpdate = Self(rawValue: kAXSelectedCellsChangedNotification)
    public static let rowSelectionDidUpdate = Self(rawValue: kAXSelectedRowsChangedNotification)
    public static let columnSelectionDidUpdate = Self(rawValue: kAXSelectedColumnsChangedNotification)

    // Generic element and hierarchy events.
    public static let elementDidAppear = Self(rawValue: kAXCreatedNotification)
    public static let elementDidDisappear = Self(rawValue: kAXUIElementDestroyedNotification)
    public static let elementBusyStatusDidUpdate = Self(rawValue: kAXElementBusyChangedNotification)
    public static let elementDidResize = Self(rawValue: kAXResizedNotification)
    public static let elementDidMove = Self(rawValue: kAXMovedNotification)
    public static let selectedChildrenDidMove = Self(rawValue: kAXSelectedChildrenMovedNotification)
    public static let childrenSelectionDidUpdate = Self(rawValue: kAXSelectedChildrenChangedNotification)
    public static let textSelectionDidUpdate = Self(rawValue: kAXSelectedTextChangedNotification)
    public static let titleDidUpdate = Self(rawValue: kAXTitleChangedNotification)
    public static let valueDidUpdate = Self(rawValue: kAXValueChangedNotification)

    // Layout events.
    public static let unitsDidUpdate = Self(rawValue: kAXUnitsChangedNotification)
    public static let layoutDidChange = Self(rawValue: kAXLayoutChangedNotification)

    // Announcement events.
    public static let applicationDidAnnounce = Self(rawValue: kAXAnnouncementRequestedNotification)

    /// Payload key.
    public struct PayloadKey: Identifier {
        public let rawValue: String

        public static let announcement = Self(rawValue: kAXAnnouncementKey)
    }
}
