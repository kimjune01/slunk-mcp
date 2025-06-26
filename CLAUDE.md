# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Slunk is a Swift/SwiftUI macOS application with Slack monitoring and accessibility features that includes MCP (Model Context Protocol) server capabilities.

## Development Commands

### Swift Application

```bash
# Build the macOS app
xcodebuild -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift build

# Run the app directly
open /Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-*/Build/Products/Debug/slunk-swift.app

# Run tests
xcodebuild test -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift
```

## Architecture

### Swift Application

- Standard SwiftUI macOS app structure
- Main app entry: `slunk-swift/slunk-swift/slunk_swiftApp.swift`
- UI entry: `slunk-swift/slunk-swift/ContentView.swift`
- Features MCP server management, accessibility testing, and Slack monitoring UI

#### Slack Monitoring System

- **SlackMonitoringService**: Real-time Slack application detection and monitoring
  - Location: `slunk-swift/slunk-swift/SlackScraper/Observer/SlackMonitoringService.swift`
  - Detects Slack by bundle ID and application name
  - Monitors application focus state (active/inactive)
  - Polling interval: 1 second for responsive detection
  - Provides detailed console logging and UI status updates

#### Accessibility Framework

- **AccessibilityManager**: Handles macOS accessibility permissions
- **ElementMatchers**: Pattern matching for UI elements
- **SlackUIParser**: Parses Slack interface elements
- **DeadlineManager**: Manages operation timeouts
- Comprehensive test suite for all accessibility components

#### Database Architecture

- **SQLiteVec Integration**: Modern SQLite with vector search capabilities
- **GRDB Configuration**: Custom SQLite build with snapshot support
- **SlackDatabaseSchema**: Comprehensive message storage with deduplication
  - `slack_messages`: Core message table with metadata and versioning
  - `slack_reactions`: Emoji reactions with counts
  - `slack_message_embeddings`: Vector embeddings for semantic search
  - `ingestion_log`: Session tracking and statistics
- **Message Deduplication**: SHA256 content hashing prevents duplicates while tracking edits

#### Contextual Search Architecture (Phase 1)

- **SlackQueryService**: Actor-based search service with comprehensive filtering
  - Location: `slunk-swift/slunk-swift/Database/SlackQueryService.swift`
  - **QueryFilter system**: Channel, user, time range, message type, reactions, attachments
  - **SearchMode options**: Semantic (vector similarity), structured (SQL), hybrid (combined)
  - **Result types**: Message, contextual message, structured, conversation chunk
  - **SearchMetadata**: Tracks result counts, context enhancement, and search performance
- **MessageContextualizer**: Context enhancement and conversation analysis
  - Location: `slunk-swift/slunk-swift/Services/MessageContextualizer.swift`
  - **ThreadContext extraction**: Captures thread hierarchy and recent message flow
  - **ConversationChunk creation**: Groups related messages by time windows and topic shifts
  - **Short message interpretation**: Provides context for emoji, "LGTM", "+1", etc.
  - **Channel context mapping**: Maps channels to topics for enhanced meaning
- **Enhanced EmbeddingService**: Async vector generation with error handling
  - **512-dimensional vectors**: Uses Apple's NLEmbedding for semantic similarity
  - **Async API**: `generateEmbedding(for:) async throws -> [Float]`
  - **Input validation**: Rejects empty/whitespace text with proper error messages

### Project Configuration

#### Swift Package Dependencies

- **SQLiteVec**: Vector search extension for SQLite
- **GRDB**: Swift SQLite toolkit with custom SQLite configuration
- **MCP SDK**: Model Context Protocol Swift implementation
- **AXSwift**: Accessibility API bindings
- **Swifter**: HTTP server for development
- **Configuration Files**:
  - `GRDBCustomSQLite-USER.xcconfig`: GRDB build settings
  - `GRDBCustomSQLite-USER.h`: Custom SQLite header configuration

## Key Integration Points

The MCP server is designed to be consumed by Claude Desktop or other MCP clients. The Swift app provides a complete MCP server implementation with stdio transport and real-time Slack monitoring capabilities.

## Current Status & Features

### ✅ Implemented Features

1. **MCP Server Integration**: Full stdio transport MCP server
2. **Slack Detection**: Real-time monitoring with bundle ID and name detection
3. **Accessibility Framework**: Complete accessibility API integration
4. **Slack Message Parsing**: Enhanced extraction with reactions, mentions, attachments
5. **Database Integration**: SQLiteVec + GRDB for vector search and relational storage
6. **Message Deduplication**: SHA256-based content hashing with edit tracking
7. **UI Management**: SwiftUI interface for server control and monitoring
8. **Test Suite**: Comprehensive testing for all components
9. **Phase 1 Contextual Search**: Complete contextual semantic search infrastructure
   - **SlackQueryService**: Actor-based search with filtering and result management
   - **MessageContextualizer**: Thread context enhancement and conversation chunking
   - **Enhanced EmbeddingService**: Async API with 512-dimensional NLEmbedding vectors
   - **Contextual meaning extraction**: Solves short message problem (emoji, "LGTM", etc.)
   - **Multi-mode search**: Semantic, structured, and hybrid search capabilities

### ✅ Recently Completed

- **Phase 2**: MCP tools for Slack querying with 4 comprehensive tools
- **Phase 3**: Advanced query processing with natural language interface
  - **Enhanced Query Parser**: 7 intent types, regex-based channel/user extraction
  - **Conversational Search**: Multi-turn sessions with context awareness
  - **Pattern Discovery**: Automated conversation pattern analysis
  - **Search Intelligence**: Refinement suggestions and related content discovery

### 🔧 Manual Testing

#### Slack Monitoring Test

1. Launch the app: `open /path/to/slunk-swift.app`
2. Click "🔍 Start Slack Monitoring"
3. Open/close Slack or switch focus
4. Observe real-time console output:
   - ✅ `SLACK DETECTED! Slack is active and ready for monitoring`
   - 🟡 `Slack is running but not in focus`
   - 🔍 `Scanning for Slack... (not currently running)`

#### Accessibility Testing

1. Click "🧪 Run Tests" in the app
2. Grant accessibility permissions when prompted
3. View detailed test results in the UI and system console

## Available MCP Tools

The MCP server provides 13 tools across three phases of development:

### Phase 1 - Core Search Tools

- **`searchConversations`** - Natural language conversation search with semantic similarity
  - Parameters: `query` (required), `limit` (optional, default: 10)

### Phase 2 - Contextual Search Tools

- **`search_messages`** - Advanced Slack message search with filtering and context
  - Parameters: `query` (required), `channels`, `users`, `start_date`, `end_date`, `search_mode`, `limit`
- **`get_thread_context`** - Extract complete thread conversations with context
  - Parameters: `thread_id` (required), `include_context` (optional, default: true)
- **`get_message_context`** - Get contextual meaning for short messages
  - Parameters: `message_id` (required), `include_thread` (optional, default: true)

### Phase 3 - Advanced Query Processing Tools

- **`parse_natural_query`** - Parse natural language to extract intent and entities
  - Parameters: `query` (required), `include_entities`, `include_temporal` (optional)
- **`intelligent_search`** - Advanced search combining NL understanding with context
  - Parameters: `query` (required), `context`, `refine_previous`, `limit`
- **`discover_patterns`** - Discover conversation patterns and recurring themes
  - Parameters: `time_range`, `pattern_type`, `min_occurrences`
- **`suggest_related`** - Suggest related conversations based on context
  - Parameters: `reference_messages`, `query_context`, `suggestion_type`, `limit`
- **`conversational_search`** - Multi-turn conversational search with refinement
  - Parameters: `query` (required), `session_id`, `action`, `refinement`, `limit`

## Testing MCP Functionality

```bash
# Test initialize method
echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | /path/to/slunk-swift.app/Contents/MacOS/slunk-swift

# Test tools list
echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}' | /path/to/slunk-swift.app/Contents/MacOS/slunk-swift

# Test basic tools
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"swiftVersion","arguments":{}},"id":3}' | /path/to/slunk-swift.app/Contents/MacOS/slunk-swift

# Test search functionality
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"searchConversations","arguments":{"query":"test message","limit":5}},"id":4}' | /path/to/slunk-swift.app/Contents/MacOS/slunk-swift
```

The app's UI provides a "Copy Config" button that generates the complete MCP server configuration JSON ready for use in `claude_desktop_config.json`.
