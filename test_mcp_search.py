#!/usr/bin/env python3
import json
import subprocess
import time

# Path to the MCP server
MCP_SERVER_PATH = "/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift"

def send_request(process, request):
    """Send a request to the MCP server and get response"""
    request_str = json.dumps(request) + "\n"
    process.stdin.write(request_str.encode())
    process.stdin.flush()
    
    # Read response
    response_line = process.stdout.readline().decode().strip()
    if response_line:
        return json.loads(response_line)
    return None

def test_search():
    # Start the MCP server
    process = subprocess.Popen(
        [MCP_SERVER_PATH, "--mcp"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    try:
        # Give it a moment to start
        time.sleep(1)
        
        # Initialize
        print("1. Initializing MCP server...")
        init_request = {
            "jsonrpc": "2.0",
            "method": "initialize",
            "params": {"capabilities": {}},
            "id": 1
        }
        response = send_request(process, init_request)
        print(f"Initialize response: {json.dumps(response, indent=2)}\n")
        
        # Test 1: Search with hybrid mode (default)
        print("2. Testing search with query 'hiring contractors'...")
        search_request = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "search_messages",
                "arguments": {
                    "query": "hiring contractors",
                    "channels": ["jobs (channel)"],
                    "limit": 5,
                    "search_mode": "hybrid"
                }
            },
            "id": 2
        }
        response = send_request(process, search_request)
        print(f"Search response: {json.dumps(response, indent=2)}\n")
        
        # Test 2: Search without channel filter
        print("3. Testing search without channel filter...")
        search_request2 = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "search_messages",
                "arguments": {
                    "query": "contractors contributors LangGraph",
                    "limit": 5,
                    "search_mode": "hybrid"
                }
            },
            "id": 3
        }
        response = send_request(process, search_request2)
        print(f"Search response 2: {json.dumps(response, indent=2)}\n")
        
        # Test 3: Use searchConversations (which we know uses hybrid search)
        print("4. Testing searchConversations...")
        search_request3 = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "searchConversations",
                "arguments": {
                    "query": "hiring job opening position recruit contractors",
                    "limit": 5
                }
            },
            "id": 4
        }
        response = send_request(process, search_request3)
        print(f"SearchConversations response: {json.dumps(response, indent=2)}\n")
        
    finally:
        # Clean up
        process.terminate()
        process.wait()

if __name__ == "__main__":
    print("Testing MCP Server Search Functionality\n")
    print("Make sure slunk-swift app is running first!\n")
    test_search()