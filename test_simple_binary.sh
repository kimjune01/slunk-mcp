#!/bin/bash

APP_PATH="/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift"

echo "🧪 Simple Binary Test"
echo "===================="

echo "Testing if binary can be executed at all..."

# Test 1: Can we execute it?
echo "Test 1: Basic execution test (will timeout)"
timeout 1s "$APP_PATH" --mcp 2>&1 | head -3 || echo "Timeout or error as expected"

echo ""
echo "Test 2: With environment variable"
MCP_MODE=1 timeout 1s "$APP_PATH" 2>&1 | head -3 || echo "Timeout or error"

echo ""
echo "Test 3: Check what prints to stderr during startup"
MCP_MODE=1 "$APP_PATH" 2>/tmp/test_stderr.log &
PID=$!
sleep 2
kill $PID 2>/dev/null || true

echo "Stderr contents:"
cat /tmp/test_stderr.log 2>/dev/null || echo "No stderr output"

echo ""
echo "Test 4: Check stdout"  
MCP_MODE=1 "$APP_PATH" >/tmp/test_stdout.log 2>&1 &
PID=$!
sleep 2  
kill $PID 2>/dev/null || true

echo "Combined output:"
cat /tmp/test_stdout.log 2>/dev/null || echo "No output"

echo ""
echo "Test 5: Process status check"
MCP_MODE=1 "$APP_PATH" &
PID=$!
sleep 1
echo "Process $PID status:"
ps -p $PID 2>/dev/null || echo "Process not found/died"
kill $PID 2>/dev/null || true

rm -f /tmp/test_stderr.log /tmp/test_stdout.log

echo ""
echo "✅ Simple tests complete"