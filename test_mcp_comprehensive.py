#!/usr/bin/env python3
"""
Comprehensive test for all Slunk MCP tools
"""
import json
import subprocess
import sys
import time
import os
import signal

APP_PATH = "/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift"

def test_mcp_tools():
    print("🧪 Testing Slunk MCP Server - All Tools")
    print("=" * 50)
    
    # Test data for each tool
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
        },
        {
            "name": "get_thread_context",
            "request": {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {"name": "get_thread_context", "arguments": {"thread_id": "1234567890.123456"}},
                "id": 5
            }
        },
        {
            "name": "get_message_context",
            "request": {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {"name": "get_message_context", "arguments": {"message_id": "1234567890.123456"}},
                "id": 6
            }
        },
        {
            "name": "parse_natural_query",
            "request": {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {"name": "parse_natural_query", "arguments": {"query": "what did alice say in engineering?"}},
                "id": 7
            }
        },
        {
            "name": "discover_patterns",
            "request": {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {"name": "discover_patterns", "arguments": {"time_range": "week"}},
                "id": 8
            }
        },
        {
            "name": "suggest_related",
            "request": {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {"name": "suggest_related", "arguments": {"query_context": "API discussion"}},
                "id": 9
            }
        },
        {
            "name": "conversational_search",
            "request": {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {"name": "conversational_search", "arguments": {"query": "test"}},
                "id": 10
            }
        }
    ]
    
    results = {}
    
    for test_case in test_cases:
        name = test_case["name"]
        request = test_case["request"]
        
        print(f"\n🔧 Testing: {name}")
        print(f"📤 Request ID: {request['id']}")
        
        try:
            # Set environment for MCP mode
            env = os.environ.copy()
            env['MCP_MODE'] = '1'
            
            # Create the request string
            request_str = json.dumps(request) + '\n'
            
            # Start process
            process = subprocess.Popen(
                [APP_PATH],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True
            )
            
            # Send request with timeout
            try:
                stdout, stderr = process.communicate(input=request_str, timeout=15)
                
                if stdout.strip():
                    print(f"✅ Response received: {stdout[:200]}...")
                    results[name] = {"status": "success", "response": stdout}
                else:
                    print(f"⚠️  No response received")
                    results[name] = {"status": "no_response", "stderr": stderr}
                    
                if stderr.strip():
                    print(f"🔍 Debug info: {stderr[:200]}...")
                    
            except subprocess.TimeoutExpired:
                print(f"⏱️  Timeout after 15 seconds")
                process.kill()
                results[name] = {"status": "timeout"}
                
        except Exception as e:
            print(f"❌ Error: {e}")
            results[name] = {"status": "error", "error": str(e)}
    
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
    
    return results

if __name__ == "__main__":
    test_mcp_tools()