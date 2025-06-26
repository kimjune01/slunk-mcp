#!/usr/bin/env python3
"""
Simple test script for Slunk MCP server
"""
import json
import subprocess
import sys
import time
import signal
import os

APP_PATH = "/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift"

def test_mcp_tool(tool_name, request_data):
    print(f"\n🔧 Testing: {tool_name}")
    print(f"📤 Request: {json.dumps(request_data, indent=2)}")
    
    try:
        # Set environment for MCP mode
        env = os.environ.copy()
        env['MCP_MODE'] = '1'
        
        # Start the MCP server process
        process = subprocess.Popen(
            [APP_PATH],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            text=True,
            bufsize=0
        )
        
        # Send the request
        request_json = json.dumps(request_data) + '\n'
        
        try:
            # Write request and close stdin to signal end
            stdout, stderr = process.communicate(input=request_json, timeout=10)
            
            print(f"📥 Response: {stdout}")
            if stderr:
                print(f"🔍 Debug: {stderr}")
                
        except subprocess.TimeoutExpired:
            print("⚠️  Request timed out")
            process.kill()
            stdout, stderr = process.communicate()
            if stderr:
                print(f"🔍 Debug: {stderr}")
                
    except Exception as e:
        print(f"❌ Error: {e}")

def main():
    print("🧪 Testing Slunk MCP Server Tools")
    print("==================================")
    
    # Test 1: Initialize
    test_mcp_tool("Initialize", {
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {}
        },
        "id": 1
    })
    
    # Test 2: Tools List
    test_mcp_tool("Tools List", {
        "jsonrpc": "2.0",
        "method": "tools/list",
        "params": {},
        "id": 2
    })
    
    # Test 3: searchConversations
    test_mcp_tool("searchConversations", {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "searchConversations",
            "arguments": {
                "query": "test message",
                "limit": 5
            }
        },
        "id": 3
    })
    
    print("\n✅ MCP Tool Testing Complete")

if __name__ == "__main__":
    main()