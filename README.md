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

## Build Instructions

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later
- Command Line Tools installed (`xcode-select --install`)

### Building from Command Line

1. **Debug Build** (for development):
   ```bash
   cd slunk-swift
   xcodebuild -project slunk-swift.xcodeproj -scheme slunk-swift -configuration Debug build
   ```

2. **Release Build** (optimized):
   ```bash
   cd slunk-swift
   xcodebuild -project slunk-swift.xcodeproj -scheme slunk-swift -configuration Release build
   ```

3. **Clean Build** (if needed):
   ```bash
   xcodebuild -project slunk-swift.xcodeproj -scheme slunk-swift clean build
   ```

### Building from Xcode

1. Open `slunk-swift/slunk-swift.xcodeproj` in Xcode
2. Select the `slunk-swift` scheme
3. Choose Debug or Release configuration from the scheme menu
4. Press ⌘B to build or ⌘R to build and run

### Build Output Location

The built app will be located in:
- **Debug**: `~/Library/Developer/Xcode/DerivedData/slunk-swift-*/Build/Products/Debug/slunk-swift.app`
- **Release**: `~/Library/Developer/Xcode/DerivedData/slunk-swift-*/Build/Products/Release/slunk-swift.app`

To find the exact path:
```bash
xcodebuild -project slunk-swift/slunk-swift.xcodeproj -showBuildSettings | grep BUILD_DIR
```

## Quick Start

1. **Build the app** (see Build Instructions above)

2. **Run the app (GUI Mode):**
   ```bash
   # Using the build output path from above
   open ~/Library/Developer/Xcode/DerivedData/slunk-swift-*/Build/Products/Release/slunk-swift.app
   
   # Or if you've copied it to Applications
   open /Applications/slunk-swift.app
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
   Replace `/path/to/slunk-swift.app` with your actual build output path.
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

## Testing

### Swift Tests
```bash
# Run all tests
xcodebuild test -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift

# Quick smoke test
xcodebuild test -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift \
  -only-testing:slunk-swiftTests/MCPIntegrationTests

# Key attribution tests (prove semantic search works)
xcodebuild test -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift \
  -only-testing:slunk-swiftTests/WorkingRoundTripTest \
  -only-testing:slunk-swiftTests/SimpleSemanticDemo
```

### Test Coverage
- **Core functionality**: MCP server, database operations, embeddings
- **Smoke tests**: Basic MCP integration, end-to-end search workflow
- **Attribution tests**: Semantic similarity demonstrations with visual output

## Development

See [CLAUDE.md](CLAUDE.md) for development instructions and architecture details.

## License

MIT
