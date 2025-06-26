# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Slunk is a Swift/SwiftUI macOS application that monitors Slack in real-time and provides intelligent search capabilities through an MCP (Model Context Protocol) server. It stores messages locally with SQLite and offers 9 comprehensive search tools.

## Development Commands

### Build & Run

```bash
# Build the macOS app
xcodebuild -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift build

# Run the app directly
open /Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-*/Build/Products/Debug/slunk-swift.app

# Clean build
xcodebuild -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift clean

# Run tests
xcodebuild test -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift
```

### Debug Logs

```bash
# View real-time debug logs
tail -f ~/Documents/slunk_debug.log

# Check database contents
sqlite3 ~/Library/Application\ Support/Slunk/slack_store.db "SELECT COUNT(*) FROM slack_messages;"
```

## Architecture

### Core Components

- **SwiftUI App**: `ContentView.swift` - Main UI with database stats
- **MCP Server**: `MCPServer.swift` - Handles JSON-RPC communication
- **Slack Monitoring**: `SlackMonitoringService.swift` - Real-time message capture
- **Database**: `SlackDatabaseSchema.swift` - SQLiteVec storage with deduplication

### Key Services

1. **SlackMonitoringService** (`SlackScraper/Observer/`)
   - Monitors Slack application state every second
   - Extracts messages using accessibility API
   - Logs to `~/Documents/slunk_debug.log`
   - Auto-starts database cleanup service (2-month retention)

2. **SlackQueryService** (`Database/`)
   - Actor-based concurrent search
   - Three search modes: semantic, structured, hybrid
   - Handles all MCP tool queries

3. **MessageContextualizer** (`Services/`)
   - Enhances short messages with context
   - Extracts thread relationships
   - Groups conversations by topic

4. **QueryParser** (`Services/`)
   - Natural language understanding
   - Entity extraction (channels, users, dates)
   - 7 intent types for query classification

### Database Schema

```sql
-- Main message table
slack_messages (
    id TEXT PRIMARY KEY,           -- Slack timestamp
    workspace TEXT,
    channel TEXT,
    sender TEXT,
    content TEXT,
    timestamp DATETIME,
    thread_ts TEXT,
    content_hash TEXT,             -- SHA256 for deduplication
    version INTEGER
)

-- Vector embeddings
slack_message_embeddings (
    embedding float[512],          -- NLEmbedding vectors
    message_id TEXT
)
```

## MCP Tools (9 Total)

### Basic Search
- `searchConversations` - Natural language search

### Advanced Search
- `search_messages` - Filtered search (channels, users, dates)
- `get_thread_context` - Full thread extraction
- `get_message_context` - Short message interpretation

### Intelligence Layer
- `parse_natural_query` - NLP query parsing
- `intelligent_search` - Context-aware search
- `conversational_search` - Multi-turn sessions

### Analytics
- `discover_patterns` - Pattern analysis
- `suggest_related` - Related content discovery

## Testing MCP Integration

```bash
# Test MCP server
echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | /path/to/slunk-swift

# List available tools
echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}' | /path/to/slunk-swift

# Search messages
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"searchConversations","arguments":{"query":"API discussion"}},"id":3}' | /path/to/slunk-swift
```

## Common Issues

1. **Database errors**: Check if `~/Library/Application Support/Slunk/` directory exists
2. **No messages captured**: Verify Slack is running and accessibility permissions granted
3. **MCP not working**: Ensure app is built in Debug configuration

## File Locations

- **Database**: `~/Library/Application Support/Slunk/slack_store.db`
- **Debug logs**: `~/Documents/slunk_debug.log`
- **MCP config**: Add to `~/Library/Application Support/Claude/claude_desktop_config.json`