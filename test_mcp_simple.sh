#!/bin/bash

APP_PATH="/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift"

echo "🧪 Testing Slunk MCP Server - Simple Test"
echo "=========================================="

# Kill any existing processes
pkill -f slunk-swift 2>/dev/null || true
sleep 1

echo "🚀 Starting MCP server in background..."
export MCP_MODE=1
$APP_PATH > /tmp/mcp_output.log 2>&1 &
MCP_PID=$!

echo "⏳ Waiting for server to initialize (10 seconds)..."
sleep 10

echo "📤 Sending initialize command..."
echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}},"id":1}' > /tmp/mcp_input.json

# Send via stdin
if kill -0 $MCP_PID 2>/dev/null; then
    echo "✅ Process is running"
    cat /tmp/mcp_input.json | timeout 5s nc -U /dev/stdin 2>/dev/null || echo "Direct input attempt"
else
    echo "❌ Process died during initialization"
fi

echo "📥 Checking output..."
if [ -f /tmp/mcp_output.log ]; then
    echo "Output log contents:"
    cat /tmp/mcp_output.log
else
    echo "No output log found"
fi

echo "🧹 Cleaning up..."
kill $MCP_PID 2>/dev/null || true
rm -f /tmp/mcp_output.log /tmp/mcp_input.json

echo "✅ Test complete"