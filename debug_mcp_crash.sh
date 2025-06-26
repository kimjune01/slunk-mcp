#!/bin/bash

APP_PATH="/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift"

echo "🔍 Debugging MCP Server Crash"
echo "=============================="

# Check if we can run it directly without MCP mode first
echo "🧪 Testing normal app launch (should fail/timeout):"
timeout 3s "$APP_PATH" 2>&1 | head -5 || echo "Normal launch timed out as expected"

echo ""
echo "🧪 Testing with MCP_MODE environment variable:"
export MCP_MODE=1

# Try with different approaches
echo "Approach 1: Direct execution with timeout"
timeout 3s "$APP_PATH" 2>&1 | head -5 || echo "MCP mode timed out or crashed"

echo ""
echo "Approach 2: Check what the app is trying to do"
# Let's see if it's trying to access something it can't
dtruss -f -n "$APP_PATH" 2>&1 | head -10 &
DTRUSS_PID=$!
sleep 2
kill $DTRUSS_PID 2>/dev/null || true

echo ""
echo "🔍 Checking app bundle structure:"
ls -la "$APP_PATH/../.."

echo ""
echo "🔍 Checking if there are any missing frameworks:"
otool -L "$APP_PATH" | head -10

echo ""
echo "✅ Debug complete"