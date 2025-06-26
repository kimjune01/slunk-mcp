#!/bin/bash

APP_PATH="/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift"
LOG_FILE="/tmp/slunk_mcp_test.log"

echo "🧪 Testing Slunk MCP Server with Detailed Logging"
echo "================================================="

# Clean up any existing processes and files
pkill -f slunk-swift 2>/dev/null || true
rm -f "$LOG_FILE"
sleep 1

echo "🚀 Starting MCP server with detailed logging..."
echo "Log file: $LOG_FILE"

# Start with full environment and logging
export MCP_MODE=1
export RUST_LOG=debug

echo "Starting at $(date)" > "$LOG_FILE"
echo "Environment: MCP_MODE=$MCP_MODE" >> "$LOG_FILE"
echo "Command: $APP_PATH" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Start the app and capture all output
$APP_PATH >> "$LOG_FILE" 2>&1 &
MCP_PID=$!

echo "📝 Process ID: $MCP_PID"
echo "⏳ Waiting 5 seconds for initialization..."
sleep 5

echo "📊 Checking if process is still running..."
if kill -0 $MCP_PID 2>/dev/null; then
    echo "✅ Process is still running"
    
    echo "📤 Attempting to send initialize command..."
    echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}},"id":1}' >> "$LOG_FILE"
    
    # Try to send a command via stdin pipe
    echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}},"id":1}' | timeout 3s cat > /proc/$MCP_PID/fd/0 2>/dev/null || echo "Failed to write to stdin"
    
    sleep 2
    
    echo "📤 Trying tools/list command..."
    echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}' >> "$LOG_FILE"
    
    sleep 2
else
    echo "❌ Process died during initialization"
fi

echo ""
echo "📋 Log file contents:"
echo "===================="
cat "$LOG_FILE"

echo ""
echo "🔍 Checking for any error files..."
ls -la /tmp/slunk* 2>/dev/null || echo "No additional temp files found"

echo ""
echo "🧹 Cleaning up..."
kill $MCP_PID 2>/dev/null || true
sleep 1
pkill -f slunk-swift 2>/dev/null || true

echo "✅ Test complete"
echo "📄 Log file preserved at: $LOG_FILE"