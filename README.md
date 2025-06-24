# Slunk

A hybrid project consisting of a Python MCP server and Swift macOS application.

## Swift macOS Application

### Prerequisites
- Xcode (latest version recommended)
- macOS development environment

### Build Commands

```bash
# Build the macOS app
xcodebuild -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift build

# Build for specific destination (optional)
xcodebuild -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift -destination "platform=macOS" build
```

### Test Commands

```bash
# Run unit tests
xcodebuild test -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift

# Run tests with specific destination
xcodebuild test -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift -destination "platform=macOS"

# Run UI tests only
xcodebuild test -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift -only-testing:slunk-swiftUITests

# Run unit tests only  
xcodebuild test -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift -only-testing:slunk-swiftTests
```

### Run Application

```bash
# Build and run the app (creates .app bundle in build directory)
xcodebuild -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift build
open slunk-swift/build/Release/slunk-swift.app

# Alternative: Use derived data location
xcodebuild -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift -configuration Release -derivedDataPath ./build build
open ./build/Build/Products/Release/slunk-swift.app
```

## Python MCP Server

### Prerequisites
- Python 3.13+
- uv package manager

### Commands

```bash
# Install dependencies
cd slunk-mcp
uv pip install -r requirements.txt

# Run the MCP server
uv run server.py

# Lint code
uv run ruff check .

# Format code
uv run ruff format .
```