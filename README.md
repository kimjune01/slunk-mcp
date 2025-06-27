# Slunk - Real-time Slack Search & Analytics for macOS

Slunk is a Swift-based macOS application that provides intelligent Slack search and analytics through an MCP (Model Context Protocol) server. It monitors Slack in real-time, stores messages locally with automatic deduplication, and offers advanced search capabilities through 8 comprehensive MCP tools.

## Key Features

- **🔍 Real-time Slack Monitoring** - Automatic message capture and database storage
- **💾 Local SQLite Database** - Messages stored with deduplication and 2-month retention
- **🤖 8 MCP Search Tools** - Natural language search, filtering, pattern discovery
- **🧠 Semantic Search** - Apple's NLEmbedding with 512-dimensional vectors for true semantic matching
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
- 8 comprehensive MCP tools for search and analysis
- SwiftUI interface with database statistics

## Quick Start

1. **Build the app:**
   ```bash
   cd slunk-swift
   xcodebuild -project slunk-swift.xcodeproj -scheme slunk-swift -configuration Release build
   ```

2. **Run the app (GUI Mode):**
   ```bash
   open /path/to/slunk-swift.app
   ```
   The app will appear in your menu bar with a # icon.

3. **Configure Claude Desktop (MCP Server Mode):**
   Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:
   ```json
   {
     "mcpServers": {
       "slunk-swift": {
         "command": "/path/to/slunk-swift.app/Contents/MacOS/slunk-swift",
         "args": ["--mcp"]
       }
     }
   }
   ```
   Then restart Claude Desktop.

## Running Modes

Slunk runs in two distinct modes:

- **GUI Mode** (default): Menu bar app with real-time Slack monitoring
- **MCP Server Mode** (`--mcp` flag): JSON-RPC server for Claude integration

Both modes share the same SQLite database, so the GUI app populates data that the MCP server queries.

## MCP Tools

The 8 MCP tools provide comprehensive Slack search capabilities:

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
- **`conversational_search`** - Multi-turn search sessions with refinement

### Analytics & Discovery
- **`discover_patterns`** - Find recurring topics and communication patterns
- **`suggest_related`** - Discover related conversations and follow-ups

## Architecture

- **Swift + SwiftUI** - Native macOS application
- **Dual-Mode Design** - GUI app for monitoring, MCP server for queries
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
