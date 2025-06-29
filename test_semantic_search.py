#!/usr/bin/env python3
import json
import subprocess
import time

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
        print(f"Initialize response: Success\n")
        
        # Test 1: Original query that was failing
        print("2. Testing original query 'hiring jobs looking for developers contractors'...")
        search_request = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "searchConversations",
                "arguments": {
                    "query": "hiring jobs looking for developers contractors",
                    "limit": 5
                }
            },
            "id": 2
        }
        response = send_request(process, search_request)
        
        if response and "result" in response and "content" in response["result"]:
            content = response["result"]["content"][0]["text"]
            print(f"Results:\n{content}\n")
        else:
            print(f"Full response: {json.dumps(response, indent=2)}\n")
        
        # Test 2: Direct semantic search for contractor message
        print("3. Testing semantic search for 'LangGraph AutoGen CrewAI agent memory'...")
        search_request2 = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "search_messages",
                "arguments": {
                    "query": "LangGraph AutoGen CrewAI agent memory persistence",
                    "search_mode": "semantic",
                    "limit": 5
                }
            },
            "id": 3
        }
        response = send_request(process, search_request2)
        
        if response and "result" in response and "content" in response["result"]:
            content = response["result"]["content"][0]["text"]
            print(f"Results:\n{content}\n")
        else:
            print(f"Full response: {json.dumps(response, indent=2)}\n")
        
        # Test 3: Hybrid search
        print("4. Testing hybrid search for 'contractors contributors'...")
        search_request3 = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "search_messages",
                "arguments": {
                    "query": "contractors contributors",
                    "search_mode": "hybrid",
                    "limit": 5
                }
            },
            "id": 4
        }
        response = send_request(process, search_request3)
        
        if response and "result" in response and "content" in response["result"]:
            content = response["result"]["content"][0]["text"]
            print(f"Results:\n{content}\n")
        else:
            print(f"Full response: {json.dumps(response, indent=2)}\n")
        
    finally:
        # Clean up
        process.terminate()
        process.wait()

if __name__ == "__main__":
    print("=== Testing Semantic Search After Embedding Backfill ===\n")
    test_search()