#!/usr/bin/env python3
"""Comprehensive verification of all MCP tools"""

import subprocess
import json
import time
import sys

class MCPToolVerifier:
    def __init__(self):
        self.proc = None
        self.test_results = {}
        
    def start_server(self):
        """Start the MCP server"""
        print("Starting MCP server...")
        self.proc = subprocess.Popen(
            ['/Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-hbeqpnnlvrrmfkftkscwaikwwclb/Build/Products/Release/slunk-swift.app/Contents/MacOS/slunk-swift', '--mcp'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=0
        )
        time.sleep(3)
        
    def send_request(self, method, params=None, request_id=1):
        """Send a request and get response"""
        request = json.dumps({
            "jsonrpc": "2.0",
            "method": method,
            "params": params or {},
            "id": request_id
        })
        
        self.proc.stdin.write(request + '\n')
        self.proc.stdin.flush()
        
        # Wait for response
        start_time = time.time()
        while time.time() - start_time < 10:  # 10 second timeout
            line = self.proc.stdout.readline()
            if line:
                try:
                    return json.loads(line)
                except json.JSONDecodeError:
                    continue
        return None
        
    def verify_tool(self, tool_name, test_params):
        """Verify a single tool"""
        print(f"\n📋 Testing {tool_name}...")
        
        response = self.send_request("tools/call", {
            "name": tool_name,
            "arguments": test_params
        })
        
        if response is None:
            print(f"  ❌ No response received")
            self.test_results[tool_name] = "TIMEOUT"
            return False
            
        if 'error' in response:
            error_msg = response['error'].get('message', 'Unknown error')
            print(f"  ❌ Error: {error_msg}")
            self.test_results[tool_name] = f"ERROR: {error_msg}"
            return False
            
        if 'result' in response:
            # Check if we got content
            content = response['result'].get('content', [])
            if content and len(content) > 0:
                text = content[0].get('text', '')
                if text:
                    # Show first 100 chars
                    preview = text[:100] + "..." if len(text) > 100 else text
                    print(f"  ✅ Success! Response preview: {preview}")
                    self.test_results[tool_name] = "SUCCESS"
                    return True
                else:
                    print(f"  ⚠️  Empty response content")
                    self.test_results[tool_name] = "EMPTY_RESPONSE"
            else:
                print(f"  ⚠️  No content in response")
                self.test_results[tool_name] = "NO_CONTENT"
                
        return False
        
    def run_all_tests(self):
        """Run all tool tests"""
        print("\n" + "="*60)
        print("MCP TOOL VERIFICATION")
        print("="*60)
        
        self.start_server()
        
        # 1. Initialize
        print("\n1️⃣  Initializing MCP server...")
        init_response = self.send_request("initialize")
        if init_response and 'result' in init_response:
            server_info = init_response['result']['serverInfo']
            print(f"  ✅ Server: {server_info['name']} v{server_info['version']}")
        else:
            print("  ❌ Failed to initialize!")
            return
            
        # 2. List tools
        print("\n2️⃣  Listing available tools...")
        tools_response = self.send_request("tools/list", {}, 2)
        if tools_response and 'result' in tools_response:
            tools = tools_response['result']['tools']
            print(f"  ✅ Found {len(tools)} tools")
            for i, tool in enumerate(tools, 1):
                print(f"     {i}. {tool['name']}")
        else:
            print("  ❌ Failed to list tools!")
            return
            
        # 3. Test each tool
        print("\n3️⃣  Testing each tool...")
        
        tool_tests = [
            {
                "name": "searchConversations",
                "params": {"query": "test message", "limit": 5},
                "description": "Natural language search"
            },
            {
                "name": "search_messages", 
                "params": {"query": "API", "channels": ["general"], "limit": 5},
                "description": "Filtered message search"
            },
            {
                "name": "get_thread_context",
                "params": {"thread_id": "1234567890.123456", "include_context": True},
                "description": "Thread retrieval"
            },
            {
                "name": "get_message_context",
                "params": {"message_id": "1234567890.123456", "include_thread": True},
                "description": "Message context analysis"
            },
            {
                "name": "parse_natural_query",
                "params": {"query": "messages from john in #general yesterday", "include_entities": True},
                "description": "Query parsing"
            },
            {
                "name": "conversational_search",
                "params": {"query": "show API discussions", "action": "search", "limit": 5},
                "description": "Conversational search"
            },
            {
                "name": "discover_patterns",
                "params": {"time_range": "week", "pattern_type": "topics", "min_occurrences": 2},
                "description": "Pattern discovery"
            },
            {
                "name": "suggest_related",
                "params": {"query_context": "API documentation", "suggestion_type": "similar", "limit": 5},
                "description": "Related content suggestions"
            }
        ]
        
        for i, test in enumerate(tool_tests, 3):
            self.verify_tool(test['name'], test['params'])
            
    def print_summary(self):
        """Print test summary"""
        print("\n" + "="*60)
        print("TEST SUMMARY")
        print("="*60)
        
        success_count = sum(1 for result in self.test_results.values() if result == "SUCCESS")
        total_count = len(self.test_results)
        
        print(f"\nTotal tools tested: {total_count}")
        print(f"Successful: {success_count}")
        print(f"Failed: {total_count - success_count}")
        
        print("\nDetailed results:")
        for tool, result in self.test_results.items():
            status = "✅" if result == "SUCCESS" else "❌"
            print(f"  {status} {tool}: {result}")
            
        print("\n" + "="*60)
        
        if success_count == total_count:
            print("🎉 ALL TOOLS VERIFIED SUCCESSFULLY!")
        else:
            print(f"⚠️  {total_count - success_count} tools need attention")
            
        print("="*60)
        
    def cleanup(self):
        """Cleanup server process"""
        if self.proc:
            self.proc.terminate()
            self.proc.wait()

def main():
    verifier = MCPToolVerifier()
    try:
        verifier.run_all_tests()
        verifier.print_summary()
    except Exception as e:
        print(f"\n❌ Error during testing: {e}")
    finally:
        verifier.cleanup()

if __name__ == "__main__":
    main()