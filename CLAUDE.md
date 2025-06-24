# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Slunk is a hybrid project consisting of:
1. A Python-based MCP (Model Context Protocol) server using FastMCP
2. A Swift/SwiftUI iOS application

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
# Build the iOS app
xcodebuild -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift build

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
- Standard SwiftUI app structure
- Main app entry: `slunk-swift/slunk-swift/slunk_swiftApp.swift`
- UI entry: `slunk-swift/slunk-swift/ContentView.swift`
- Currently displays a basic "Hello, world!" view

### Project Configuration
- Python dependencies managed by `uv` (see `pyproject.toml` and `uv.lock`)
- MCP server integration configured in `claude-config.json`
- Python 3.13+ required
- Ruff configured with 88-character line length

## Key Integration Points

The MCP server is designed to be consumed by Claude Desktop or other MCP clients. The Swift app provides a complete MCP server implementation with stdio transport.

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