#!/bin/bash

APP_PATH="/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift"

echo "🧪 Testing Slunk MCP Server - Direct Communication"
echo "=================================================="

# Create named pipes for communication
INPIPE=$(mktemp -u)
OUTPIPE=$(mktemp -u)
mkfifo "$INPIPE"
mkfifo "$OUTPIPE"

# Cleanup function
cleanup() {
    rm -f "$INPIPE" "$OUTPIPE"
    pkill -f "slunk-swift" 2>/dev/null || true
}
trap cleanup EXIT

echo "🚀 Starting MCP server..."
# Start MCP server with environment variable
export MCP_MODE=1
"$APP_PATH" < "$INPIPE" > "$OUTPIPE" 2>&1 &
MCP_PID=$!

# Give it time to initialize
echo "⏳ Waiting for initialization..."
sleep 5

echo "📤 Sending initialize command..."
echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}},"id":1}' > "$INPIPE" &

# Read response
echo "📥 Reading response..."
timeout 5s cat "$OUTPIPE" | head -10

echo ""
echo "📤 Sending tools/list command..."
echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}' > "$INPIPE" &

# Read response
echo "📥 Reading response..."
timeout 5s cat "$OUTPIPE" | head -10

echo ""
echo "📤 Sending searchConversations command..."
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"searchConversations","arguments":{"query":"test","limit":3}},"id":3}' > "$INPIPE" &

# Read response
echo "📥 Reading response..."
timeout 5s cat "$OUTPIPE" | head -10

echo ""
echo "✅ Test complete"