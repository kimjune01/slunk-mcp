#!/bin/bash

# Test script for Slunk MCP tools
APP_PATH="/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift"

echo "🧪 Testing Slunk MCP Server Tools"
echo "=================================="

# Function to test MCP command
test_mcp_command() {
    local command_name="$1"
    local request="$2"
    echo ""
    echo "🔧 Testing: $command_name"
    echo "📤 Request: $request"
    echo "📥 Response:"
    echo "$request" | timeout 10s "$APP_PATH" --mcp 2>/dev/null
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
        echo "⚠️  Command timed out"
    elif [ $exit_code -ne 0 ]; then
        echo "❌ Command failed with exit code: $exit_code"
    fi
    echo ""
}

# 1. Test initialization
test_mcp_command "Initialize" '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{"roots":{"listChanged":true},"sampling":{},"experimental":{}}},"id":1}'

# 2. Test tools list
test_mcp_command "Tools List" '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}'

# 3. Test searchConversations
test_mcp_command "searchConversations" '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"searchConversations","arguments":{"query":"test message","limit":5}},"id":3}'

# 4. Test search_messages
test_mcp_command "search_messages" '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"search_messages","arguments":{"query":"test","limit":5}},"id":4}'

# 5. Test get_thread_context  
test_mcp_command "get_thread_context" '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_thread_context","arguments":{"thread_id":"1234567890.123456"}},"id":5}'

# 6. Test get_message_context
test_mcp_command "get_message_context" '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_message_context","arguments":{"message_id":"1234567890.123456"}},"id":6}'

# 7. Test parse_natural_query
test_mcp_command "parse_natural_query" '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"parse_natural_query","arguments":{"query":"what did alice say in engineering channel last week?"}},"id":7}'

# 8. Test discover_patterns
test_mcp_command "discover_patterns" '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"discover_patterns","arguments":{"time_range":"week"}},"id":8}'

# 9. Test suggest_related
test_mcp_command "suggest_related" '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"suggest_related","arguments":{"query_context":"API discussion"}},"id":9}'

# 10. Test conversational_search (should be disabled)
test_mcp_command "conversational_search" '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"conversational_search","arguments":{"query":"test"}},"id":10}'

echo "✅ MCP Tool Testing Complete"