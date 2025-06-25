# Practical Implementation Plan for Slunk Query Interface

## Current Reality Check

### What We Have
- Basic semantic search (`searchConversations`)
- SQLite with vector storage
- Slack content extraction via accessibility APIs
- Simple text ingestion

### What We Actually Need (MVP)
1. **Structured filtering** - Find messages by channel, user, date
2. **Better data extraction** - Capture reactions, threads, attachments
3. **Proper error messages** - Help LLM agents recover from failures

## Implementation Order (What I'll Actually Do)

### Step 1: Fix the Data Model First (Day 1-2)

**Why**: Can't query data we don't store

**Files to modify**:
```
slunk-swift/slunk-swift/SlackModels.swift
slunk-swift/slunk-swift/VectorStorage/SQLiteVecSchema.swift
```

**Specific changes**:
1. Extend `SlackMessage` to include:
   - reactions: `[String: Int]` (emoji -> count)
   - thread_ts: `String?`
   - attachments: `[SlackAttachment]`
   - mentions: `[String]`

2. Add to SQLite schema:
   ```sql
   CREATE TABLE reactions (
     message_id TEXT,
     emoji TEXT,
     count INTEGER
   );
   
   CREATE TABLE attachments (
     message_id TEXT,
     type TEXT,
     title TEXT,
     url TEXT
   );
   ```

**How to test**: 
- Create unit test with mock Slack data
- Verify all fields persist and retrieve correctly

### Step 2: Enhance Slack Extraction (Day 3-4)

**Why**: Need to actually capture the new data

**Files to modify**:
```
slunk-swift/slunk-swift/SlackScraper/Parsers/SlackMessageParser.swift
```

**Specific changes**:
1. Look for reaction elements in accessibility tree
2. Detect attachment indicators
3. Parse @mentions in message text
4. Extract thread indicators

**How to test**:
- Use AccessibilityInspector on real Slack
- Create test cases for different message types
- Log what we're missing and iterate

### Step 3: Add Structured Query Tool (Day 5-7)

**Why**: This is the core missing feature

**New file**:
```
slunk-swift/slunk-swift/MCP/Tools/StructuredQueryTool.swift
```

**Implementation approach**:
```swift
struct StructuredQueryParameters {
    let channels: [String]?
    let users: [String]?
    let startDate: Date?
    let endDate: Date?
    let hasReactions: Bool?
    let hasAttachments: Bool?
    let limit: Int = 20
}

func buildSQLQuery(params: StructuredQueryParameters) -> String {
    // Start simple, add filters incrementally
    var query = "SELECT * FROM messages WHERE 1=1"
    
    if let channels = params.channels {
        query += " AND channel IN (" + channels.map { "'\($0)'" }.joined(separator: ",") + ")"
    }
    // ... etc
}
```

**How to test**:
- Start with single filter queries
- Test combinations
- Verify performance with EXPLAIN QUERY PLAN

### Step 4: Update MCP Server (Day 8)

**Why**: Wire up the new tool

**File to modify**:
```
slunk-swift/slunk-swift/MCP/MCPServer.swift
```

**Changes**:
1. Add `query_slack_structured` to tools list
2. Handle the new tool in `handleToolCall`
3. Return results in the agreed format

**How to test**:
- Send JSON-RPC requests via stdin
- Verify response format matches spec
- Test error cases

### Step 5: Add Time Range Helpers (Day 9)

**Why**: "last 7 days" is way more natural than ISO dates

**Add to structured query tool**:
```swift
enum TimeRange {
    case lastNDays(Int)
    case between(Date, Date)
    case since(Date)
    
    func toSQLCondition() -> String {
        // Convert to SQL WHERE clause
    }
}
```

**How to test**:
- Test each time range type
- Verify timezone handling
- Check edge cases (DST, etc.)

### Step 6: Improve Error Handling (Day 10)

**Why**: Current errors are useless for LLM agents

**Create error types**:
```swift
enum QueryError: Error {
    case noChannelFound(String, alternatives: [String])
    case invalidTimeRange(String)
    case tooManyResults(Int, suggestion: String)
    
    var userMessage: String {
        // Helpful message with suggestions
    }
}
```

**How to test**:
- Trigger each error type
- Verify messages are helpful
- Test recovery suggestions work

## What I'm NOT Implementing (Yet)

1. **Hybrid queries** - Structured + semantic is good enough separately
2. **Analytics/trends** - Can build later on top of structured queries  
3. **AI summarization** - Let the LLM agent handle this
4. **Fancy ranking** - Start with simple timestamp ordering
5. **Export formats** - JSON is sufficient for MVP

## Testing Strategy (Realistic)

### Manual Testing Checklist
- [ ] Open real Slack, extract different message types
- [ ] Run queries via command line, verify results
- [ ] Test with 1K, 10K messages to find performance issues
- [ ] Have an LLM agent use it, see what breaks

### Automated Tests (Minimal but Critical)
```swift
// Test data model
func testMessageWithReactions()
func testThreadExtraction()

// Test queries  
func testChannelFilter()
func testDateRangeFilter()
func testCombinedFilters()

// Test MCP protocol
func testStructuredQueryTool()
func testErrorResponses()
```

## Quick Wins First

1. **Day 1**: Just add reactions to the data model - immediate value
2. **Day 2**: Add channel filtering - most requested feature
3. **Day 3**: Time range helpers - huge UX improvement

## How to Know We're Done (MVP)

- [x] Can filter messages by channel
- [x] Can filter messages by date range  
- [x] Can search within specific users' messages
- [x] Reactions and threads are captured
- [x] Errors tell you what went wrong and how to fix it
- [x] An LLM agent can use it without getting stuck

## Next Steps After MVP

1. Add more filters (has_attachments, has_reactions)
2. Performance optimization (better indexes)
3. Result pagination 
4. Channel listing tool
5. Basic analytics (message counts by day)

## File Change Summary

**Modified files** (in order):
1. `SlackModels.swift` - Extend data model
2. `SQLiteVecSchema.swift` - Add tables
3. `SlackMessageParser.swift` - Extract more data
4. `MCPServer.swift` - Add new tool

**New files**:
1. `StructuredQueryTool.swift` - Core query logic
2. `TimeRangeHelper.swift` - Date parsing utilities
3. `QueryError.swift` - Better error types

**Test files**:
1. `StructuredQueryTests.swift`
2. `SlackExtractionTests.swift`

Total: ~1000-1500 lines of focused code, not 10 weeks of architecture astronomy.