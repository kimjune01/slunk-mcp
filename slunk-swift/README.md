# Slunk Swift - Slack Content Extraction & Vector Search

A macOS application that extracts Slack conversations and provides semantic search capabilities through an MCP (Model Context Protocol) server.

## Overview

Slunk combines real-time Slack content extraction with a powerful vector database to enable semantic search across your Slack conversations. It monitors Slack activity, captures conversations (including threaded replies), and makes them searchable through natural language queries.

## Key Features

### 🔍 **Slack Content Extraction**
- **Real-time monitoring** of active Slack windows
- **Complete conversation capture** including main channels and thread sidebars  
- **Automatic parsing** of messages, senders, timestamps, and thread context
- **Multi-workspace support** with workspace and channel detection

### 🧠 **Semantic Search & Vector Database**
- **512-dimensional vector embeddings** using Apple's NLEmbedding
- **Natural language queries** like "Swift async patterns from yesterday"
- **Hybrid search** combining semantic similarity, keywords, and temporal filters
- **Smart organization** with automatic keyword extraction and entity recognition

### 🤖 **MCP Server Integration**
- **Three MCP tools** for searching, ingesting, and analyzing conversations
- **JSON-RPC 2.0** protocol over stdio for Claude Desktop integration
- **Production-ready** error handling and logging
- **Sandboxed environment** with no external network access

### ⚡ **Performance & Reliability**
- **Query latency < 200ms** with optimized SQLiteVec database
- **Concurrent operations** support with actor-based architecture
- **Comprehensive error handling** and automatic retry logic
- **Resource monitoring** and automatic database maintenance

## Architecture

```
┌─────────────────┐     ┌──────────────────┐
│  Claude Desktop │────▶│   MCP Server     │
└─────────────────┘     └──────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │  ProductionService    │
                    └───────────────────────┘
                         │    │    │
           ┌─────────────┴────┴────┴──────────────┐
           ▼             ▼              ▼          ▼
    ┌──────────┐  ┌─────────────┐  ┌─────────┐  ┌────────┐
    │  Query   │  │  Ingestion  │  │  Slack  │  │ Logger │
    │  Engine  │  │   Service   │  │ Monitor │  │        │
    └──────────┘  └─────────────┘  └─────────┘  └────────┘
           │             │              │
           └─────────────┴──────────────┘
                         │
                  ┌──────────────┐
                  │  SQLiteVec   │
                  │   Database   │
                  └──────────────┘
```

## Quick Start

### Prerequisites
- macOS 15.5+ (for Sonnet 4 usage)
- Xcode 15.0+
- Accessibility permissions for Slack content extraction

### Building & Running

1. **Clone and build:**
   ```bash
   git clone <repository-url>
   cd slunk-swift
   xcodebuild -project slunk-swift.xcodeproj -scheme slunk-swift build
   ```

2. **Run the application:**
   ```bash
   open slunk-swift/Build/Products/Debug/slunk-swift.app
   ```

3. **Configure Claude Desktop:**
   - Click "Copy Config" button in the app
   - Add the configuration to your `claude_desktop_config.json`
   - Restart Claude Desktop

### Claude Desktop Configuration

Add this to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "slunk": {
      "command": "/path/to/slunk-swift.app/Contents/MacOS/slunk-swift",
      "args": []
    }
  }
}
```

## Usage

### Starting Slack Monitoring

1. **Grant accessibility permissions** when prompted
2. **Start Slack Monitoring** from the app interface
3. **Enable Content Parsing** to begin capturing conversations
4. **Use Slack normally** - conversations are captured automatically

### Searching with Claude

Once configured, use these MCP tools in Claude Desktop:

```
# Search conversations
"Search for discussions about Swift concurrency from last week"

# Get statistics
"How many Slack conversations have been captured?"

# Manual content ingestion (optional)
"Ingest this meeting summary: [content]"
```

### Natural Language Queries

The system understands various query patterns:
- **Semantic**: "React performance optimization tips"
- **Temporal**: "conversations from yesterday", "last week's discussions"
- **People**: "messages from John about the API design"
- **Topics**: "database migration strategies"

## Development

### Project Structure

- **`SlackScraper/`** - Slack content extraction and monitoring
  - `Accessibility/` - UI parsing using LBAccessibility framework
  - `Observer/` - Real-time Slack application monitoring
  - `Models/` - Data models for Slack content
  
- **`Services/`** - Core business logic
  - `EmbeddingService.swift` - Vector embedding generation
  - `NaturalLanguageQueryEngine.swift` - Query processing
  - `SmartIngestionService.swift` - Content ingestion with NLP
  - `ProductionService.swift` - Main service coordinator

- **`Database/`** - Vector database implementation
  - `SQLiteVecSchema.swift` - SQLiteVec integration

- **`Performance/`** - Optimization and monitoring
  - `DatabaseOptimizer.swift` - Database performance tuning
  - `MemoryMonitor.swift` - Resource monitoring

### Running Tests

```bash
# Run all tests
xcodebuild test -project slunk-swift.xcodeproj -scheme slunk-swift

# Run integration tests specifically
xcodebuild test -project slunk-swift.xcodeproj -scheme slunk-swift -testPlan ProductionIntegrationTests
```

### Development Tools

The app includes built-in testing and monitoring:
- **🧪 Run Tests** button for comprehensive testing
- **Real-time Slack monitoring** status and logs
- **Content extraction preview** showing captured messages
- **MCP server configuration** generation

## Documentation

- **[PRODUCTION_README.md](PRODUCTION_README.md)** - Detailed production deployment guide
- **[IMPLEMENTATION_COMPLETE.md](IMPLEMENTATION_COMPLETE.md)** - Complete implementation overview
- **[CLAUDE.md](CLAUDE.md)** - Claude Code integration instructions

## License

[Add your license information here]

## Contributing

[Add contributing guidelines here]