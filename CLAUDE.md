# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Slunk is a hybrid project consisting of:
1. A Python-based MCP (Model Context Protocol) server using FastMCP
2. A Swift/SwiftUI macOS application with Slack monitoring and accessibility features

## Development Commands

### Python MCP Server

```bash
# Run the MCP server
uv run server.py

# Install dependencies
uv pip install -r requirements.txt

# Run linting
uv run ruff check .

# Format code
uv run ruff format .
```

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

### MCP Server (`server.py`)
- Uses FastMCP framework to create an MCP server named "slunk"
- Currently implements a single `ping_slunk` tool
- Configured to run via `uv` in `claude-config.json`
- Entry point: `server.py:14` - `mcp.run()`

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

### Project Configuration
- Python dependencies managed by `uv` (see `pyproject.toml` and `uv.lock`)
- MCP server integration configured in `claude-config.json`
- Python 3.13+ required
- Ruff configured with 88-character line length

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

### 🚧 In Development
- Structured query tools for filtered message retrieval
- Advanced semantic search capabilities
- Time-based query helpers

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

## Testing MCP Functionality

To verify the MCP server works correctly:

```bash
# Test initialize method
echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | /path/to/slunk-swift.app/Contents/MacOS/slunk-swift

# Test tools list
echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}' | /path/to/slunk-swift.app/Contents/MacOS/slunk-swift

# Test swiftVersion tool
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"swiftVersion","arguments":{}},"id":3}' | /path/to/slunk-swift.app/Contents/MacOS/slunk-swift

# Test createNote tool
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"createNote","arguments":{"title":"Test","content":"Hello World"}},"id":4}' | /path/to/slunk-swift.app/Contents/MacOS/slunk-swift
```

The app's UI provides a "Copy Config" button that generates the complete MCP client configuration JSON ready for use in `claude_desktop_config.json`.