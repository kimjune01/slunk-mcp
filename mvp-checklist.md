# MVP Implementation Checklist

## Day 1-2: Data Model ✓ When Done

### SlackModels.swift
- [ ] Add `reactions: [String: Int]` to SlackMessage
- [ ] Add `threadTimestamp: String?` to SlackMessage  
- [ ] Add `attachments: [SlackAttachment]` struct and array
- [ ] Add `mentions: [String]` to SlackMessage

### SQLiteVecSchema.swift
- [ ] Add reactions table with (message_id, emoji, count)
- [ ] Add attachments table with (message_id, type, title, url)
- [ ] Create indexes on message_id for both tables
- [ ] Write migration for existing databases

### Quick Test
```bash
# After implementation, test with:
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"ingestText","arguments":{"text":"Test message with 👍 reaction"}},"id":1}' | ./slunk-swift
```

## Day 3-4: Slack Extraction ✓ When Done

### SlackMessageParser.swift
- [ ] Find reaction elements (look for "reaction" in accessibility description)
- [ ] Extract reaction emoji and count
- [ ] Detect attachment indicators (paperclip icon, file names)
- [ ] Parse @mentions from message text with regex
- [ ] Identify thread messages (look for "replies" indicator)

### Manual Test
- [ ] Open Slack with a message containing reactions
- [ ] Open Slack with a thread
- [ ] Open Slack with attachments
- [ ] Verify extraction captures all elements

## Day 5-7: Structured Query ✓ When Done

### Create StructuredQueryTool.swift
- [ ] Define parameter struct with channels, users, dates, etc.
- [ ] Implement SQL query builder (start with single conditions)
- [ ] Add JOIN for reactions and attachments
- [ ] Format results to match interface spec
- [ ] Handle empty results gracefully

### Basic Queries to Implement
- [ ] Filter by channel: `WHERE channel = ?`
- [ ] Filter by user: `WHERE user_id = ?`
- [ ] Filter by date: `WHERE timestamp BETWEEN ? AND ?`
- [ ] Filter by reactions: `WHERE message_id IN (SELECT message_id FROM reactions)`
- [ ] Combine filters with AND

## Day 8: Wire Up MCP ✓ When Done

### MCPServer.swift
- [ ] Add `query_slack_structured` to toolsList()
- [ ] Add case in handleToolCall()
- [ ] Parse parameters from JSON
- [ ] Call StructuredQueryTool
- [ ] Return results in correct format

### Test Commands
```bash
# Test structured query
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"query_slack_structured","arguments":{"filters":{"channels":["#general"]}}},"id":1}' | ./slunk-swift

# Test with date range
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"query_slack_structured","arguments":{"filters":{"channels":["#general"]},"time_range":{"last":"7d"}}},"id":1}' | ./slunk-swift
```

## Day 9: Time Ranges ✓ When Done

### TimeRangeHelper.swift
- [ ] Parse "last 7d", "last 30d" format
- [ ] Parse ISO date strings
- [ ] Convert to SQL date conditions
- [ ] Handle timezone (use UTC)

### Test Cases
- [ ] "last": "7d" → WHERE timestamp > datetime('now', '-7 days')
- [ ] "from": "2024-01-01" → WHERE timestamp > '2024-01-01'
- [ ] "from": "2024-01-01", "to": "2024-02-01" → WHERE timestamp BETWEEN

## Day 10: Error Handling ✓ When Done

### QueryError.swift
- [ ] Create enum with helpful error cases
- [ ] Each error includes suggestion
- [ ] Format errors as JSON-RPC errors

### Error Cases to Handle
- [ ] Channel not found → list available channels
- [ ] No results → suggest broader query
- [ ] Invalid date format → show correct format
- [ ] SQL errors → user-friendly message

## Final Integration Test ✓ When Done

### Full Workflow Test
1. [ ] Start Slack and let it monitor
2. [ ] Ingest some conversations
3. [ ] Query by channel
4. [ ] Query by date range  
5. [ ] Query with multiple filters
6. [ ] Verify error messages are helpful

### LLM Agent Test
- [ ] Ask Claude to find messages from last week
- [ ] Ask Claude to search in specific channel
- [ ] Ask Claude to find messages with reactions
- [ ] Verify Claude can recover from errors

## Definition of Done

MVP is complete when:
- [ ] Can filter by channel, user, and date
- [ ] Reactions and threads are captured
- [ ] Time ranges like "last 7 days" work
- [ ] Errors are helpful and suggest fixes
- [ ] All tests pass
- [ ] Claude can use it successfully

## Not Doing (But Documenting for Later)

- Complex ranking algorithms → Using timestamp order
- Pagination → Returning first N results  
- Caching → Direct queries only
- Analytics → Can build on structured queries
- Export formats → JSON only