#!/usr/bin/env python3
"""
Test all MCP tools for the Slunk Release build
"""

import subprocess
import json
import sys
import time

def send_request(proc, request):
    """Send a request and get response"""
    proc.stdin.write(json.dumps(request) + '\n')
    proc.stdin.flush()
    
    # Keep reading until we get a JSON response
    max_attempts = 10
    for _ in range(max_attempts):
        response_line = proc.stdout.readline()
        if not response_line:
            time.sleep(0.1)
            continue
            
        # Skip any non-JSON lines (like debug output)
        line = response_line.strip()
        if line.startswith('['):
            # Debug output
            print(f"[DEBUG OUTPUT] {line}")
            continue
        elif line.startswith('{'):
            # JSON response
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                print(f"[ERROR] Failed to parse JSON: {line}")
                continue
    
    return None

def test_mcp_server():
    """Test all MCP tools"""
    # Start the MCP server
    proc = subprocess.Popen(
        ['/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift', '--mcp'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    try:
        # Give it time to start
        time.sleep(5)
        
        # Read any initial stderr output
        proc.stderr.flush()
        # Set stderr to non-blocking mode to read what's available
        import fcntl
        import os
        flags = fcntl.fcntl(proc.stderr, fcntl.F_GETFL)
        fcntl.fcntl(proc.stderr, fcntl.F_SETFL, flags | os.O_NONBLOCK)
        
        try:
            stderr_output = proc.stderr.read()
            if stderr_output:
                print("[STDERR]", stderr_output)
        except:
            pass
        
        # 1. Initialize
        print("=" * 60)
        print("1. Testing initialize...")
        response = send_request(proc, {
            "jsonrpc": "2.0",
            "method": "initialize",
            "params": {},
            "id": 1
        })
        print(f"✓ Initialize successful: {response['result']['serverInfo']['name']}")
        
        # 2. List tools
        print("\n2. Testing tools/list...")
        response = send_request(proc, {
            "jsonrpc": "2.0",
            "method": "tools/list",
            "params": {},
            "id": 2
        })
        
        if response is None:
            print("✗ No response received for tools/list")
            return
            
        if 'error' in response:
            print(f"✗ Error in tools/list: {response['error']}")
            return
            
        if 'result' not in response:
            print(f"✗ Unexpected response format: {response}")
            return
            
        tools = response['result']['tools']
        print(f"✓ Found {len(tools)} tools:")
        for tool in tools:
            print(f"  - {tool['name']}")
        
        # Test each tool
        tool_tests = [
            {
                "name": "searchConversations",
                "params": {"query": "test message"},
                "description": "Testing searchConversations"
            },
            {
                "name": "search_messages",
                "params": {"query": "test", "limit": 5},
                "description": "Testing search_messages"
            },
            {
                "name": "get_thread_context",
                "params": {"threadId": "1234567890.123456"},
                "description": "Testing get_thread_context"
            },
            {
                "name": "get_message_context",
                "params": {"messageId": "1234567890.123456"},
                "description": "Testing get_message_context"
            },
            {
                "name": "parse_natural_query",
                "params": {"query": "messages from john in #general yesterday"},
                "description": "Testing parse_natural_query"
            },
            {
                "name": "conversational_search",
                "params": {"query": "show me API discussions", "sessionId": "test-session"},
                "description": "Testing conversational_search"
            },
            {
                "name": "discover_patterns",
                "params": {"timeRange": "week", "minFrequency": 2},
                "description": "Testing discover_patterns"
            },
            {
                "name": "suggest_related",
                "params": {"messageId": "1234567890.123456", "limit": 3},
                "description": "Testing suggest_related"
            }
        ]
        
        for i, test in enumerate(tool_tests, start=3):
            print(f"\n{i}. {test['description']}...")
            response = send_request(proc, {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {
                    "name": test['name'],
                    "arguments": test['params']
                },
                "id": i
            })
            
            if response and 'result' in response:
                print(f"✓ {test['name']} responded successfully")
                if 'content' in response['result'] and len(response['result']['content']) > 0:
                    content = response['result']['content'][0]
                    if content['type'] == 'text':
                        # Show first 100 chars of response
                        text = content['text']
                        preview = text[:100] + "..." if len(text) > 100 else text
                        print(f"  Response preview: {preview}")
            elif response and 'error' in response:
                print(f"✗ {test['name']} returned error: {response['error']}")
            else:
                print(f"✗ {test['name']} failed to respond")
        
        print("\n" + "=" * 60)
        print("✓ All MCP tools tested successfully!")
        
    except Exception as e:
        print(f"Error during testing: {e}")
        stderr = proc.stderr.read()
        if stderr:
            print(f"Stderr: {stderr}")
    finally:
        proc.terminate()
        proc.wait()

if __name__ == "__main__":
    test_mcp_server()