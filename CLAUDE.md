# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Slunk is a Swift/SwiftUI macOS application that monitors Slack in real-time and provides intelligent search capabilities through an MCP (Model Context Protocol) server. It stores messages locally with SQLite and offers 8 comprehensive search tools with advanced deduplication.

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
   - Monitors Slack application state (5s active, 10s background, 30s inactive)
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
    id TEXT PRIMARY KEY,           -- Slack timestamp (e.g., 1750947252.454503)
    workspace TEXT,
    channel TEXT,
    sender TEXT,
    content TEXT,
    timestamp DATETIME,
    thread_ts TEXT,
    content_hash TEXT,             -- SHA256 of content+sender (no timestamp)
    version INTEGER
)

-- Vector embeddings
slack_message_embeddings (
    embedding float[512],          -- NLEmbedding vectors
    message_id TEXT
)
```

### Deduplication Strategy

- **Deduplication Key**: SHA256 hash of `channel:sender:content`
- **Content Hash**: SHA256 of `content+sender` (excludes timestamp)
- Prevents storing duplicate messages captured during polling intervals
- Maintains message edit history through version tracking

## MCP Tools (8 Total)

### Basic Search
- `searchConversations` - Quick natural language searches across all messages
  - Returns: `{id, title, summary, sender, timestamp, score, matchedKeywords}`

### Advanced Search
- `search_messages` - Precise searches with channel/user/date filters
  - Returns: `{id, workspace, channel, sender, content, timestamp, threadId}`
- `get_thread_context` - Retrieve complete thread conversations
  - Returns: `{threadId, parentMessage, messages[], contextualMeanings[], participants[]}`
- `get_message_context` - Understand cryptic messages/emojis with context
  - Returns: `{originalMessage, contextualMeaning, threadContext, enhancement}`

### Intelligence Layer
- `parse_natural_query` - Extract intent, entities, and dates from queries
  - Returns: `{intent, keywords[], channels[], users[], entities[], temporalHint}`
- `conversational_search` - Multi-turn search sessions with context
  - Returns: `{sessionId, results[], enhancedQuery, refinementSuggestions[], sessionContext}`

### Analytics
- `discover_patterns` - Find trending topics and communication patterns
  - Returns: `{patterns: {topics[], participants[], communication[]}, timeRange}`
- `suggest_related` - Expand searches with semantically similar content
  - Returns: `{suggestions[], referenceMessages[], queryContext, suggestionsCount}`

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

## Recent Improvements (June 2025)

### Deduplication System
- Content-based deduplication prevents storing duplicate messages
- Reduced database size by ~95% by eliminating polling duplicates
- Maintains edit history through version tracking

### Enhanced Tool Descriptions
- Clearer BEST FOR/USE WHEN/RETURNS format for all tools
- Visual decision tree for tool selection
- Concrete examples with actual parameter values
- Simplified guidance for LLM agents

### Performance Optimizations
- Polling intervals: 5s (active), 10s (background), 30s (inactive)
- Reduced CPU usage while maintaining responsiveness
- Better database query performance with proper indexing