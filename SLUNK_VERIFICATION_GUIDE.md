# Slunk App Verification Guide

Complete testing guide for Slunk's core functionality: Slack monitoring, message scraping, and MCP querying.

## 1. Download & Setup

### Build the App
```bash
cd slunk-swift
xcodebuild -project slunk-swift.xcodeproj -scheme slunk-swift build
```

### Launch the App
```bash
open /Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-*/Build/Products/Debug/slunk-swift.app
```

**Expected:** App launches with SwiftUI interface showing monitoring controls.

## 2. Permission Setup

### Grant Accessibility Permission
1. App will prompt for accessibility permission on first run
2. **Manual setup:** System Settings > Privacy & Security > Accessibility
3. Add slunk-swift.app to the list and enable it

**Verification:**
- Click "🧪 Run Tests" in the app
- Should see green checkmarks for accessibility tests
- Console should show: `✅ Accessibility permission granted`

## 3. Slack Monitoring Verification

### Test Slack Detection
1. **Ensure Slack is closed**
2. Click "🔍 Start Slack Monitoring" in slunk
3. **Expected:** Console shows `🔍 Scanning for Slack... (not currently running)`

4. **Launch Slack**
5. **Expected:** Console immediately shows `✅ SLACK DETECTED! Slack is active and ready for monitoring`

6. **Switch to another app** (minimize Slack)
7. **Expected:** Console shows `🟡 Slack is running but not in focus`

8. **Return to Slack**
9. **Expected:** Console shows `✅ SLACK DETECTED! Slack is active and ready for monitoring`

### Verify Real-time Monitoring
- Status updates every 1 second
- App UI shows current Slack state
- Console provides detailed logging

## 4. Auto Scraping Verification

### Database Setup Check
1. Check if SQLite database exists at expected location
2. Verify database schema is created

**Commands:**
```bash
# Find the database file
find ~/Library -name "*.db" -path "*/slunk*" 2>/dev/null

# Check schema (if found)
sqlite3 /path/to/database.db ".schema"
```

**Expected tables:**
- `slack_messages`
- `slack_reactions` 
- `slack_message_embeddings`
- `ingestion_log`

### Message Scraping Test
1. **Have Slack open with visible messages**
2. **Start monitoring in slunk**
3. **Navigate through Slack channels with messages**
4. **Check database for scraped content**

**Verification query:**
```sql
SELECT COUNT(*) FROM slack_messages;
SELECT channel, user, LEFT(content, 50) FROM slack_messages LIMIT 5;
```

**Expected:** Messages appear in database with proper metadata.

## 5. MCP Integration Verification

### Test MCP Server
```bash
# Get the app binary path
APP_PATH="/path/to/slunk-swift.app/Contents/MacOS/slunk-swift"

# Test initialize
echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | $APP_PATH

# Test tools list
echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}' | $APP_PATH
```

**Expected:** JSON responses with MCP protocol compliance.

### Test Search Tools

#### Basic Search
```bash
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"searchConversations","arguments":{"query":"test","limit":3}},"id":3}' | $APP_PATH
```

#### Advanced Search
```bash
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"search_messages","arguments":{"query":"meeting","search_mode":"semantic","limit":5}},"id":4}' | $APP_PATH
```

**Expected:** JSON responses with message results and metadata.

## 6. Claude Desktop Integration

### Configuration Test
1. Click "Copy Config" in slunk app
2. Paste into `~/.config/claude-desktop/claude_desktop_config.json`
3. Restart Claude Desktop
4. **Expected:** Slunk tools available in Claude

### End-to-End Test
1. Ask Claude: "Search for recent messages about meetings"
2. **Expected:** Claude uses slunk MCP tools to query your Slack data
3. **Expected:** Results show actual messages from your Slack

## 7. Performance Verification

### Monitoring Performance
- **Expected:** <1% CPU usage during idle monitoring
- **Expected:** Real-time Slack state detection (1-second updates)
- **Expected:** Minimal memory footprint

### Search Performance
```bash
# Time a search operation
time echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"searchConversations","arguments":{"query":"test"}},"id":5}' | $APP_PATH
```

**Expected:** Sub-second response for semantic search.

## 8. Error Handling Verification

### Test Without Slack
1. Ensure Slack is closed
2. Try MCP search commands
3. **Expected:** Graceful error messages, not crashes

### Test Without Permissions
1. Revoke accessibility permission
2. Try monitoring
3. **Expected:** Clear error message requesting permission

## 9. Troubleshooting

### Common Issues

**Slack not detected:**
- Verify Slack app name and bundle ID match expected values
- Check Console.app for detailed monitoring logs

**No search results:**
- Verify database has content: `SELECT COUNT(*) FROM slack_messages;`
- Check if scraping is active and permissions granted

**MCP tools not working:**
- Test CLI commands directly first
- Verify Claude Desktop config is properly formatted
- Check Claude Desktop logs for connection errors

### Debug Commands
```bash
# Check running processes
ps aux | grep -E "(slunk|Slack)"

# Monitor file system access
sudo fs_usage -f pathname slunk-swift

# Check accessibility permissions
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access WHERE service='kTCCServiceAccessibility';"
```

## Success Criteria

✅ **Core Functionality:**
- Slack detection and monitoring works
- Messages are scraped and stored
- MCP server responds to queries
- Search returns relevant results

✅ **Integration:**
- Claude Desktop can use slunk tools
- Real-time monitoring updates
- Proper error handling

✅ **Performance:**
- Low resource usage
- Fast search responses
- Stable long-term operation