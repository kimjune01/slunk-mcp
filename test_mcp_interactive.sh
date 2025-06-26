#!/bin/bash

APP_PATH="/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Debug/slunk-swift.app/Contents/MacOS/slunk-swift"

echo "🧪 Interactive MCP Test"
echo "======================"

# Create named pipes for better control
INPIPE="/tmp/mcp_in"
OUTPIPE="/tmp/mcp_out"

# Clean up any existing pipes
rm -f "$INPIPE" "$OUTPIPE"
mkfifo "$INPIPE"
mkfifo "$OUTPIPE"

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up..."
    pkill -f slunk-swift 2>/dev/null || true
    rm -f "$INPIPE" "$OUTPIPE"
}
trap cleanup EXIT

echo "🚀 Starting MCP server..."
export MCP_MODE=1

# Start server with pipes
"$APP_PATH" < "$INPIPE" > "$OUTPIPE" 2>/tmp/mcp_stderr.log &
MCP_PID=$!

echo "📝 Server PID: $MCP_PID"
echo "⏳ Waiting 3 seconds for startup..."
sleep 3

echo "🔍 Checking startup logs:"
cat /tmp/mcp_stderr.log

if ! kill -0 $MCP_PID 2>/dev/null; then
    echo "❌ Server died during startup"
    exit 1
fi

echo ""
echo "📤 Sending initialize command..."
echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}},"id":1}' > "$INPIPE" &

echo "📥 Reading response (timeout 5s)..."
timeout 5s cat "$OUTPIPE" &
READER_PID=$!

sleep 5
kill $READER_PID 2>/dev/null || true

echo ""
echo "📤 Sending tools/list command..."
echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}' > "$INPIPE" &

echo "📥 Reading response (timeout 5s)..."
timeout 5s cat "$OUTPIPE" | head -10

echo ""
echo "🔍 Final server logs:"
cat /tmp/mcp_stderr.log

echo ""
echo "✅ Test complete"