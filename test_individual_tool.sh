#!/bin/bash

# Test individual MCP tool
APP_PATH="/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift"

# Create a temporary file for communication
TEMP_INPUT=$(mktemp)
TEMP_OUTPUT=$(mktemp)

# Clean up on exit
cleanup() {
    rm -f "$TEMP_INPUT" "$TEMP_OUTPUT"
    pkill -f "slunk-swift --mcp" 2>/dev/null || true
}
trap cleanup EXIT

echo "🧪 Testing Individual MCP Tool: $1"
echo "================================="

# Start MCP server in background
"$APP_PATH" --mcp < "$TEMP_INPUT" > "$TEMP_OUTPUT" 2>&1 &
MCP_PID=$!

# Give it a moment to start
sleep 1

# Send initialization
echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}},"id":1}' > "$TEMP_INPUT"
sleep 1

# Send the test command
echo "$2" >> "$TEMP_INPUT"
sleep 2

# Read output
echo "📥 Output:"
cat "$TEMP_OUTPUT"

# Clean up
kill $MCP_PID 2>/dev/null || true