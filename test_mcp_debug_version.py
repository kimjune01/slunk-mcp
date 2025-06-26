#!/usr/bin/env python3
"""
Test MCP tools with the working debug version
"""
import json
import subprocess
import sys
import time
import os
import signal

APP_PATH = "/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Debug/slunk-swift.app/Contents/MacOS/slunk-swift"

def test_mcp_tool(tool_name, request_data, timeout=15):
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
            # Write request and get response
            stdout, stderr = process.communicate(input=request_json, timeout=timeout)
            
            if stdout.strip():
                print(f"✅ Response received:")
                print(stdout)
                return {"status": "success", "response": stdout, "stderr": stderr}
            else:
                print(f"⚠️  No stdout response")
                if stderr.strip():
                    print(f"🔍 Stderr: {stderr}")
                return {"status": "no_response", "stderr": stderr}
                
        except subprocess.TimeoutExpired:
            print(f"⏱️  Request timed out after {timeout}s")
            process.kill()
            stdout, stderr = process.communicate()
            return {"status": "timeout", "stderr": stderr}
                
    except Exception as e:
        print(f"❌ Error: {e}")
        return {"status": "error", "error": str(e)}

def main():
    print("🧪 Testing Slunk MCP Server - Debug Version")
    print("=" * 50)
    
    # Test cases
    test_cases = [
        {
            "name": "Initialize", 
            "request": {
                "jsonrpc": "2.0",
                "method": "initialize",
                "params": {"protocolVersion": "2024-11-05", "capabilities": {}},
                "id": 1
            }
        },
        {
            "name": "Tools List",
            "request": {
                "jsonrpc": "2.0",
                "method": "tools/list",
                "params": {},
                "id": 2
            }
        },
        {
            "name": "searchConversations",
            "request": {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {"name": "searchConversations", "arguments": {"query": "test", "limit": 3}},
                "id": 3
            }
        },
        {
            "name": "search_messages",
            "request": {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {"name": "search_messages", "arguments": {"query": "test", "limit": 3}},
                "id": 4
            }
        }
    ]
    
    results = {}
    for test_case in test_cases:
        name = test_case["name"]
        request = test_case["request"]
        result = test_mcp_tool(name, request)
        results[name] = result
        
        # Give some time between tests
        time.sleep(1)
    
    # Summary
    print(f"\n📊 Test Summary")
    print("=" * 30)
    successful = sum(1 for r in results.values() if r["status"] == "success")
    total = len(results)
    print(f"Successful: {successful}/{total}")
    
    for name, result in results.items():
        status_emoji = {"success": "✅", "timeout": "⏱️", "no_response": "⚠️", "error": "❌"}
        emoji = status_emoji.get(result["status"], "❓")
        print(f"{emoji} {name}: {result['status']}")

if __name__ == "__main__":
    main()