# Slunk - Real-time Slack Search & Analytics for macOS

Slunk is a Swift-based macOS application that provides intelligent Slack search and analytics through an MCP (Model Context Protocol) server. It monitors Slack in real-time, stores messages locally with automatic deduplication, and offers advanced search capabilities through 9 comprehensive MCP tools.

## Key Features

- **🔍 Real-time Slack Monitoring** - Automatic message capture and database storage
- **💾 Local SQLite Database** - Messages stored with deduplication and 2-month retention
- **🤖 9 MCP Search Tools** - Natural language search, filtering, pattern discovery
- **🧠 Semantic Search** - 512-dimensional vector embeddings for meaning-based search
- **📊 Conversation Analytics** - Pattern discovery and trend analysis
- **🔒 Privacy-First** - All data stored locally on your machine
- **⚡ High Performance** - Optimized for 100K+ messages

## Project Structure

```
slunk/
├── slunk-swift/                    # Swift macOS application
│   ├── slunk-swift/               
│   │   ├── Database/              # SQLiteVec database & search
│   │   ├── Services/              # Query processing & analytics
│   │   ├── SlackScraper/          # Slack monitoring & parsing
│   │   ├── MCPServer.swift        # MCP server implementation
│   │   └── ContentView.swift      # SwiftUI interface
│   └── slunk-swift.xcodeproj      # Xcode project
├── CLAUDE.md                       # Development instructions
└── README.md                       # This file
```

## Current Status

✅ **Fully Implemented:**
- Real-time Slack monitoring with accessibility API
- SQLite database with vector search (SQLiteVec)
- Message deduplication and automatic cleanup (2-month retention)
- 9 comprehensive MCP tools for search and analysis
- SwiftUI interface with database statistics

## Quick Start

1. **Build the app:**
   ```bash
   cd slunk-swift
   xcodebuild -project slunk-swift.xcodeproj -scheme slunk-swift build
   ```

2. **Run the app:**
   ```bash
   open /path/to/slunk-swift.app
   ```

3. **Configure Claude Desktop:**
   - Click "Copy Config" button in the app
   - Add the configuration to `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Restart Claude Desktop

## MCP Tools

The 9 MCP tools provide comprehensive Slack search capabilities:

### Basic Search
- **`searchConversations`** - Natural language search across all messages
  - Example: "Find discussions about the API redesign from last week"

### Advanced Search & Filtering  
- **`search_messages`** - Search with precise filters (channels, users, dates)
  - Example: Search #engineering channel for messages from Alice in March
- **`get_thread_context`** - Extract complete thread conversations
- **`get_message_context`** - Get meaning for short messages (emoji, "LGTM", etc.)

### Intelligent Query Processing
- **`parse_natural_query`** - Extract intent and entities from natural language
- **`intelligent_search`** - Advanced search combining NLP and context
- **`conversational_search`** - Multi-turn search sessions with refinement

### Analytics & Discovery
- **`discover_patterns`** - Find recurring topics and communication patterns
- **`suggest_related`** - Discover related conversations and follow-ups

## Architecture

- **Swift + SwiftUI** - Native macOS application
- **SQLiteVec** - Vector database for semantic search
- **GRDB** - SQLite toolkit with custom configuration  
- **Accessibility API** - Real-time Slack UI monitoring
- **MCP Protocol** - Standard protocol for AI tool integration

## Requirements

- macOS 13.0+
- Xcode 15.0+
- Slack desktop app
- Accessibility permissions for Slack monitoring

## Privacy & Security

- All data stored locally in `~/Library/Application Support/Slunk/`
- No external API calls or cloud storage
- Automatic cleanup of messages older than 2 months
- Messages are deduplicated by content hash

## Development

See [CLAUDE.md](CLAUDE.md) for development instructions and architecture details.

## License

MIT
