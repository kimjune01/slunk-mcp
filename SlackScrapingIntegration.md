# Slack Scraping Integration for Slunk

This document outlines the implementation of Slack message scraping functionality using the accessibility-based scraper framework, designed for integration into the Slunk MCP server application.

## Overview

The Slack scraping system uses macOS Accessibility APIs to extract real-time conversation data from the Slack desktop application. This approach captures live conversations, messages, threads, and workspace information without requiring API tokens or direct Slack integration.

## Architecture

### Core Components

#### 1. SlackParser (`SlackParser.swift`)
The main parser actor that handles Slack-specific UI element extraction:

- **Actor-based design**: Thread-safe message processing using Swift's actor model
- **Window type detection**: Distinguishes between main Slack windows and child windows (huddles, pop-ups)
- **Workspace awareness**: Extracts team and workspace context for proper message attribution
- **Thread support**: Handles both regular messages and threaded conversations

#### 2. Element Parsing Rules (`ElementParsingRules.swift`)
Provides the foundational framework for UI element matching and data extraction:

- **Rule-based matching**: Flexible pattern matching for UI elements
- **Collector system**: Type-safe data collection with various specialized collectors
- **Traversal engine**: Efficient DOM tree traversal with deadline management
- **Matcher composition**: Combinable matchers for complex UI element identification

#### 3. FrontmostAppObserver (`FrontmostAppObserver.swift`)
Comprehensive application monitoring and detection system:

- **Real-time app switching detection**: Uses NSWorkspace notifications to detect when applications become frontmost
- **Window focus tracking**: Monitors window changes, moves, resizes, and title updates
- **Element focus observation**: Tracks focused UI elements within applications for precise data extraction
- **Multi-level observation**: Hierarchical monitoring of applications → windows → elements
- **Automatic cleanup**: Proper task cancellation and resource management when apps switch

#### 4. FrontmostAppTraversal (`FrontmostAppTraversal.swift`)
Orchestrates the complete app monitoring and data collection pipeline:

- **Periodic scanning**: Configurable interval-based app content capture (default 5 seconds)
- **Event-driven capture**: Immediate capture when apps or windows change focus
- **Content filtering**: Built-in privacy controls and content exclusion rules
- **Deduplication**: Hash-based content deduplication to avoid sending duplicate data
- **System sleep/wake handling**: Pauses and resumes monitoring during system sleep cycles

### Key Features

#### Message Extraction
```swift
// Example of message structure captured
Message(
    sender: "John Doe",
    content: "Meeting starts in 5 minutes in room B",
    timestamp: "2024-01-15T10:30:00Z", 
    messageType: "message",
    timestring: "Yesterday at 10:30 AM"
)
```

#### Workspace Context
- Automatically detects current workspace/team
- Handles multi-workspace Slack installations
- Preserves channel hierarchy and context

#### Thread Handling
- Identifies threaded conversations
- Captures thread metadata (reply counts, participants)
- Maintains thread context in message classification

#### Real-time Processing
- Deadline-based processing to ensure responsiveness
- Incremental message processing
- State management for sender/timestamp continuity

## Integration Points for Slunk

### 1. MCP Tool Implementation

Add a new tool to the Slunk MCP server for Slack message retrieval:

```python
@mcp.tool("get_slack_messages")
async def get_slack_messages(
    workspace: str = None,
    channel: str = None,
    limit: int = 50
) -> dict:
    """Extract recent Slack messages from the active Slack application"""
    # Integration with Swift scraper
    result = await slack_scraper.parse_current_window()
    return {
        "conversations": result.active_conversations,
        "timestamp": datetime.now().isoformat()
    }
```

### 2. Data Model Integration

The scraper outputs structured conversation data:

```swift
struct ParseResult {
    let activeConversations: [Conversation]?
}

struct Conversation {
    let app: String          // "Slack"
    let channel: String      // "Team Name, #general"
    let messages: [Message]  // Array of message objects
}
```

### 3. Privacy and Permissions

#### Required macOS Permissions
- **Accessibility Access**: Required for UI element inspection
- **Screen Recording**: May be required for some accessibility features

#### Implementation Considerations
- All processing happens locally on the user's machine
- No data transmission to external servers
- User must explicitly grant accessibility permissions

## Technical Implementation

### App Detection and Monitoring System

The scraper uses a sophisticated multi-layered approach to detect and monitor applications:

#### Application Detection Flow
```swift
// 1. NSWorkspace notification subscription for app switching
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification,
    object: nil,
    queue: OperationQueue.main
) { note in
    guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
    let appState = AppState(pid: app.processIdentifier, name: app.localizedName ?? "Unknown")
    await handleFrontmostAppChanged(appState: appState)
}

// 2. Application element creation and observation
let application = await Element(processIdentifier: appState.pid)
let observer = try await AccessObserver(element: application)

// 3. Window and element focus tracking
try await observer.subscribe(to: .windowDidGetFocus)
try await observer.subscribe(to: .elementDidGetFocus)
```

#### Multi-Level Observation Architecture
```swift
// Application Level: Monitor app switching and main window changes
private func observeFrontmostApp(appState: AppState) {
    // Creates AccessObserver for the application process
    // Subscribes to window focus events
    // Handles app state changes and window management
}

// Window Level: Track window position, size, and title changes  
private func observeMainWindow(_ window: Element, appName: String) {
    // Monitors window events: move, resize, title updates
    // Manages window content filtering and validity
    // Coordinates with element observation
}

// Element Level: Monitor focused element changes and content
private func observeFocusedElement(_ element: Element) {
    // Tracks element resize, move, selection, value updates
    // Captures real-time content changes
    // Provides granular UI interaction monitoring
}
```

#### Content Filtering and Privacy Controls
```swift
// Built-in content filtering system
guard contentFilter.shouldIncludeWindow(windowTitle: windowTitle, appName: appName) else {
    Log.debug("Window '\(windowTitle)' is filtered out for app: \(appName)")
    return
}

guard contentFilter.shouldIncludeApp(appName: appState.name) else {
    return
}
```

#### Periodic vs Event-Driven Capture
```swift
// Event-driven capture: Immediate response to focus changes
for await event in await observer.eventStream {
    switch event.notification {
    case .elementDidGetFocus:
        try await handleMainWindowAndElement(application: application, elementOverride: event.subject)
    case .windowDidGetFocus:
        try await handleMainWindowAndElement(application: application, observer: observer)
    }
}

// Periodic capture: Regular interval scanning (configurable, default 5s)
func startPeriodicSnapshot() async {
    while !Task.isCancelled {
        await snapshotAndSend(appState: currentApp, deadline: .fromNow(duration: perWindowTimeoutPeriodic))
        try await Task.sleep(for: .seconds(frontmostAppTraversalFrequency))
    }
}
```

### Slack UI Element Patterns

The parser recognizes specific Slack UI patterns:

#### Main Window Detection
```swift
// Identifies main Slack workspace window
let matchWorkspaceList = Matchers.hasAttribute(.description, equalTo: "Workspaces")
```

#### Message Structure Recognition
```swift
// Locates message content areas
Matchers.hasAttribute(.subrole, equalTo: Subrole.contentList)
```

#### Thread Identification
```swift
// Detects threaded conversations
Matchers.hasAttribute(.title, containsAny: ["reply", "replies"])
```

### Error Handling and Robustness

#### Deadline Management
- All operations respect processing deadlines
- Graceful degradation when UI elements are unavailable
- Timeout protection for accessibility operations

#### State Persistence
```swift
// Maintains context across message parsing
var lastSeenSender: String?
var lastSeenTimestamp: String?
```

#### Fallback Strategies
- Multiple parsing strategies for different Slack window types
- Graceful handling of UI changes and updates
- Comprehensive error logging for debugging

#### Task Management and Cleanup
```swift
// Proper resource management for observation tasks
private var currentAppObserverTask: Task<Void, Never>?
private var currentElementObserverTask: Task<Void, Never>?
private var currentWindowObserverTask: Task<Void, Never>?

// Automatic cleanup on app switching
func stopObservation() {
    currentAppObserverTask?.cancel()
    currentElementObserverTask?.cancel()
    currentWindowObserverTask?.cancel()
    // Reset state
    frontmostPid = nil
    focusedElement = nil
    mainWindow = nil
}
```

#### System Sleep/Wake Handling
```swift
// Pause monitoring during system sleep
NotificationCenter.default.addObserver(forName: .inAppSystemWillSleep) { _ in
    await observer.stopObservation()
    await setSleeping()
}

// Resume monitoring after wake with delay
NotificationCenter.default.addObserver(forName: .inAppSystemDidWakeUp) { _ in
    Task {
        try await Task.sleep(for: .seconds(delayAfterWake))
        if wasRunning && !isSleeping { self.run() }
    }
}
```

## Deployment Integration

### Swift Application Integration

The scraper can be integrated into the existing Swift component of Slunk:

1. **Add Scraper Dependencies**: Include the scraper framework in the Swift project
2. **MCP Bridge**: Create a bridge between Swift scraper and Python MCP server
3. **Permission Management**: Handle accessibility permission requests in the Swift UI

### Configuration Options

#### Scraping Preferences
```json
{
  "slack_scraping": {
    "enabled": true,
    "max_messages_per_channel": 100,
    "include_threads": true,
    "workspace_filter": ["work-team", "project-alpha"],
    "refresh_interval": 30
  }
}
```

#### Privacy Controls
- User-controlled scraping enable/disable
- Workspace and channel filtering
- Message content filtering options

## Security Considerations

### Data Handling
- All scraped data remains local to the user's machine
- No automatic cloud synchronization
- User controls data retention and deletion

### Access Control
- Requires explicit user permission for accessibility access
- No background scraping without user awareness
- Clear indication when scraping is active

### Compliance
- Respects Slack's terms of service for local data access
- No violation of API rate limits (uses UI scraping, not API)
- User responsible for compliance with workplace policies

## Performance Characteristics

### Processing Speed
- Real-time message extraction (< 100ms per message)
- Efficient DOM traversal with early termination
- Minimal CPU impact on Slack application performance
- Configurable capture intervals (default 5 seconds, can be reduced to 2.5s temporarily)

### Memory Usage
- Actor-based design minimizes memory overhead
- Streaming message processing
- Configurable message buffer limits
- Automatic task cancellation prevents memory leaks

### Reliability
- Robust against Slack UI updates
- Comprehensive error recovery
- Graceful degradation when accessibility is limited
- Multi-layered fallback strategies for different window types

### App Detection Performance
- **Immediate response**: NSWorkspace notifications provide instant app switching detection
- **Background monitoring**: Lightweight periodic scanning with configurable intervals
- **Smart filtering**: Content filtering reduces unnecessary processing
- **Resource efficiency**: Automatic cleanup and task management prevent resource accumulation

## Usage Examples

### Basic Message Retrieval
```python
# Get recent messages from current Slack channel
messages = await mcp_client.call_tool("get_slack_messages", {
    "limit": 20
})
```

### Workspace-Specific Scraping
```python
# Get messages from specific workspace
messages = await mcp_client.call_tool("get_slack_messages", {
    "workspace": "Engineering Team",
    "limit": 50
})
```

### Thread Analysis
```python
# Extract threaded conversations
threads = await mcp_client.call_tool("get_slack_threads", {
    "include_replies": True
})
```

## Future Enhancements

### Planned Features
- **Real-time streaming**: Live message updates as they arrive
- **Message search**: Search across scraped message history
- **Attachment handling**: Extract and process file attachments
- **Emoji and reaction support**: Capture message reactions and custom emoji

### Integration Opportunities
- **Meeting detection**: Identify and track meeting-related messages
- **Task extraction**: Parse action items and to-dos from conversations
- **Notification management**: Smart filtering of important messages
- **Cross-platform support**: Extend to Slack web client scraping

## Conclusion

The Slack scraping integration provides Slunk with powerful real-time conversation monitoring capabilities while maintaining user privacy and system performance. The accessibility-based approach ensures compatibility with Slack's desktop application without requiring API access or external dependencies.

The modular design allows for easy integration into the existing Slunk MCP server architecture, providing users with immediate access to their Slack conversation data through the familiar MCP tool interface.