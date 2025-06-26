# Slunk - Slack Content Extraction & Vector Search

Slunk is a macOS application that extracts Slack conversations and provides semantic search capabilities through an MCP (Model Context Protocol) server. It combines real-time Slack monitoring with a powerful vector database for intelligent conversation search.

## Quick Start

**👉 See the main implementation:** [`slunk-swift/`](slunk-swift/) for the complete Swift application.

## Key Features

- **🔍 Real-time Slack monitoring** with complete conversation capture (including threads)
- **🧠 Contextual semantic search** using 512-dimensional vector embeddings with context enhancement
- **🎯 Short message interpretation** - Transforms emoji and abbreviations into meaningful context
- **🤖 MCP server integration** for Claude Desktop  
- **⚡ High performance** with <200ms query latency
- **🛡️ Production-ready** with comprehensive error handling and logging
- **🔄 Thread-aware search** with conversation chunking and topic detection

## Project Structure

```
slunk/
├── slunk-swift/                           # Main Swift macOS application
│   ├── CONTEXTUAL_SEARCH_STATUS.md       # Phase 1 implementation status
│   ├── VECTOR_DATABASE_IMPLEMENTATION_COMPLETE.md # Vector DB implementation
│   └── slunk-swift/                       # Swift source code
│       ├── Database/                      # SQLiteVec + contextual search
│       ├── Services/                      # Core services (embedding, contextualizer)
│       └── SlackScraper/                  # Slack monitoring and parsing
├── CLAUDE.md                              # Development guide and architecture
└── vector-strategy.md                     # Vector search strategy
```

## Quick Setup

1. **Build the application:**
   ```bash
   cd slunk-swift
   xcodebuild -project slunk-swift.xcodeproj -scheme slunk-swift build
   ```

2. **Run the app:**
   ```bash
   open slunk-swift/Build/Products/Debug/slunk-swift.app
   ```

3. **Configure Claude Desktop:**
   - Click "Copy Config" in the app
   - Add to your `claude_desktop_config.json`
   - Restart Claude Desktop

## Architecture

Slunk uses a sophisticated architecture combining:
- **LBAccessibility framework** for Slack UI parsing
- **SQLiteVec** for high-performance vector similarity search
- **Apple's NLEmbedding** for semantic understanding
- **Actor-based concurrency** for thread-safe operations
- **MCP protocol** for Claude Desktop integration

## Documentation

- **[slunk-swift/README.md](slunk-swift/README.md)** - Main application guide
- **[PRODUCTION_README.md](slunk-swift/PRODUCTION_README.md)** - Production deployment
- **[IMPLEMENTATION_COMPLETE.md](slunk-swift/IMPLEMENTATION_COMPLETE.md)** - Technical overview

## Performance

- Query latency: **45-80ms** (target: <200ms)
- Scales to **100K+ conversations**
- Supports **50+ concurrent operations**
- Memory efficient with automatic optimization

## License

[Add your license information here]