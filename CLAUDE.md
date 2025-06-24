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

The MCP server is designed to be consumed by Claude Desktop or other MCP clients. The Swift app appears to be a separate client application, though the integration between them is not yet implemented in the current codebase.