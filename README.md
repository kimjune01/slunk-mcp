# Slunk - Real-time Slack Search for macOS

Slunk monitors Slack in real-time and provides intelligent search through an MCP server integration with Claude Desktop.

## Features

- 🔍 **Real-time monitoring** - Captures Slack messages using accessibility API
- 🧠 **Semantic search** - Apple's NLEmbedding for conceptual matching
- 💾 **Local storage** - SQLite with automatic deduplication and 2-month retention
- 🤖 **8 MCP tools** - Natural language search, analytics, and pattern discovery
- 🔒 **Privacy-first** - All data stays on your machine

## Quick Start

### Prerequisites
- macOS 13.0+, Xcode 15.0+, Slack desktop app

### Build & Run

```bash
# Build
cd slunk-swift
xcodebuild -project slunk-swift.xcodeproj -scheme slunk-swift -configuration Release build

# Run GUI (menu bar app)
open ~/Library/Developer/Xcode/DerivedData/slunk-swift-*/Build/Products/Release/slunk-swift.app

# Configure Claude Desktop
# Add to ~/Library/Application Support/Claude/claude_desktop_config.json:
{
  "mcpServers": {
    "slunk-swift": {
      "command": "/path/to/slunk-swift.app/Contents/MacOS/slunk-swift",
      "args": ["--mcp"]
    }
  }
}
```

## MCP Tools

| Tool | Purpose |
|------|---------|
| `searchConversations` | Natural language search across all messages |
| `search_messages` | Precise filtering by channel/user/date |
| `get_thread_context` | Extract complete thread conversations |
| `get_message_context` | Decode short messages and emojis |
| `parse_natural_query` | Extract intent from queries |
| `conversational_search` | Multi-turn search sessions |
| `discover_patterns` | Find trending topics |
| `suggest_related` | Discover related conversations |

## Architecture

- **GUI Mode**: Menu bar app that monitors Slack
- **MCP Mode**: JSON-RPC server for Claude integration
- **Database**: SQLiteVec with 512-dimensional embeddings
- **Storage**: `~/Library/Application Support/Slunk/`

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development instructions.

## License

MIT