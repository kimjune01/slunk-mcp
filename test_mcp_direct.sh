#\!/bin/bash

# Create a file with test requests
cat > test_requests.txt << 'INNER_EOF'
{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}
{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}
INNER_EOF

echo "Testing MCP server with direct input..."
echo "Sending requests:"
cat test_requests.txt

echo -e "\n\nStarting server and sending requests..."
cat test_requests.txt | /Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift --mcp 2>&1 | head -20

echo -e "\n\nTest complete."
