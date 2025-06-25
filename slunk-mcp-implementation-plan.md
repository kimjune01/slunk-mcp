# Slunk MCP Query Interface Implementation Plan

## Overview

This plan addresses the gaps between the designed MCP query interface (`mcp-query-interface-design.md`) and the current implementation. The plan is structured in incremental phases with comprehensive testing at each step.

## Current State Analysis

### ✅ **Implemented & Working**
- Basic semantic search (`searchConversations`)
- SQLiteVec vector search infrastructure
- Slack data models and database schema
- Natural language query processing
- Message ingestion and deduplication
- Analytics basics (`getConversationStats`)

### ❌ **Missing from Design (Priority Order)**
1. `query_slack_structured` - Structured filtering by channels, users, message types
2. `get_slack_channels` - Channel discovery and filtering
3. `query_slack_hybrid` - Enhanced semantic + structured combination
4. `get_conversation_summary` - AI-powered conversation summarization
5. `analyze_slack_trends` - Pattern analysis and trends
6. `query_slack_relationships` - User interaction networks

## Implementation Strategy

### **Phase 1: Foundation Enhancement (1-2 days)**
*Goal: Bridge existing Slack schema with search capabilities*

#### 1.1 Slack Database Query Layer
**File**: `slunk-swift/slunk-swift/Database/SlackQueryService.swift` (new)

**Implementation Steps**:
1. Create `SlackQueryService` class with methods:
   - `filterByChannels(channels: [String])`
   - `filterByUsers(users: [String])`
   - `filterByMessageTypes(types: [MessageType])`
   - `filterByTimeRange(from: Date, to: Date)`
2. Integrate with existing `SQLiteVecSchema`

**Test Strategy**:
```swift
// Tests: SlackQueryServiceTests.swift
func testChannelFiltering()
func testUserFiltering() 
func testMessageTypeFiltering()
func testTimeRangeFiltering()
```

**Verification**:
- All filter types work independently
- Filter combinations work correctly
- Unit tests pass

#### 1.2 Enhanced Search Integration
**File**: Extend `slunk-swift/slunk-swift/Database/SlackQueryService.swift` (same file)

**Implementation Steps**:
1. Add to `SlackQueryService` class:
   - `searchWithFilters(semanticQuery: String?, filters: SlackFilters, scope: SearchScope)`
   - `combineSemanticAndStructured(semanticResults: [Result], filteredResults: [Result])`
2. Define clear parameter structures and enums for filters and scopes
3. Connect to existing `NaturalLanguageQueryEngine` when semantic query is provided

**Test Strategy**:
```swift
// Tests: SlackQueryServiceTests.swift (extended)
func testStructuredFilteringOnly()
func testSemanticAndStructuredCombination()
func testScopeFiltering()
```

**Verification**:
- Structured filtering works independently
- Semantic + structured combination works
- Scope filtering routes correctly

### **Phase 2: Core Query Tools (2-3 days)**
*Goal: Implement the 3 most critical missing tools*

#### 2.1 `query_slack_structured`
**File**: `slunk-swift/slunk-swift/MCPServer.swift` (extend)

**Implementation Steps**:
1. Add tool definition in `MCPServer.swift` with parameters:
```swift
@mcp.tool
func querySlackStructured(
    channels: [String]? = nil,
    users: [String]? = nil, 
    messageTypes: [String]? = nil,
    hasAttachments: Bool? = nil,
    hasReactions: Bool? = nil,
    threadRepliesOnly: Bool? = nil,
    timeRange: TimeRange? = nil,
    sortBy: String = "timestamp",
    limit: Int = 20
) -> MCPResult
```

2. Connect to `SlackQueryService.searchWithFilters()`
3. Format results according to design document JSON structure

**Test Strategy**:
```swift
// Tests: MCPServerStructuredQueryTests.swift
func testBasicChannelFiltering()
func testUserFiltering()
func testMessageTypeFiltering() 
func testAttachmentFiltering()
func testReactionFiltering()
func testTimeRangeFiltering()
func testSortingOptions()
func testComplexFilterCombinations()
```

**Verification**:
- All filter parameters work correctly
- JSON-RPC responses match design format
- Tool integrates properly with MCP server

#### 2.2 `get_slack_channels`
**File**: `slunk-swift/slunk-swift/MCPServer.swift` (extend)

**Implementation Steps**:
1. Add tool definition in `MCPServer.swift` with parameters:
```swift
@mcp.tool
func getSlackChannels(
    type: String? = nil,          // "public", "private", "dm", "group", "all"
    memberCountMin: Int? = nil,
    includeArchived: Bool = false,
    namePattern: String? = nil,   // regex pattern
    lastActivityBefore: String? = nil  // ISO date
) -> MCPResult
```

2. Add channel query methods to `SlackQueryService`:
   - `getChannels(filters: ChannelFilters)`
   - Channel filtering and pattern matching logic
3. Format channel information response

**Test Strategy**:
```swift
// Tests: MCPServerChannelQueryTests.swift
func testChannelTypeFiltering()
func testMemberCountFiltering()
func testNamePatternMatching()
func testActivityFiltering()
func testArchivedChannelHandling()
```

**Verification**:
- Channel discovery works for all types
- Filtering accurately matches criteria
- Response format matches design

#### 2.3 Enhanced `query_slack_hybrid`
**File**: `slunk-swift/slunk-swift/MCPServer.swift` (extend existing `searchConversations`)

**Implementation Steps**:
1. Modify existing `searchConversations` tool to accept additional parameters:
```swift
@mcp.tool
func searchConversations(
    query: String,                    // existing semantic query
    channels: [String]? = nil,        // new structured filters
    users: [String]? = nil,
    hasReactions: Bool? = nil,
    timeRange: TimeRange? = nil,
    semanticWeight: Double = 0.7,     // weight semantic vs structured
    limit: Int = 10
) -> MCPResult
```

2. Use `SlackQueryService.searchWithFilters()` to combine semantic and structured results
3. Implement result ranking based on `semanticWeight` parameter

**Test Strategy**:
```swift
// Tests: MCPServerHybridQueryTests.swift
func testSemanticOnlyQuery()
func testStructuredOnlyQuery()
func testHybridWeighting()
func testResultRanking()
```

**Verification**:
- Existing semantic search still works
- Structured filters integrate properly
- Weighting affects result ranking as expected

### **Phase 3: Advanced Features (3-4 days)**
*Goal: Implement conversation summarization*

#### 3.1 `get_conversation_summary`
**Files**: 
- `slunk-swift/slunk-swift/Services/ConversationSummarizer.swift` (new)
- `slunk-swift/slunk-swift/MCPServer.swift` (extend)

**Implementation Steps**:
1. Create `ConversationSummarizer` class with methods:
   - `summarizeConversation(conversationId: String, summaryType: SummaryType)`
   - `extractActionItems(messages: [SlackMessage])`
   - `extractDecisions(messages: [SlackMessage])`

2. Add MCP tool in `MCPServer.swift`:
```swift
@mcp.tool
func getConversationSummary(
    conversationId: String,           // channel ID or thread timestamp
    timeRange: TimeRange? = nil,
    summaryType: String = "brief",    // "brief", "detailed", "action_items", "decisions"
    maxLength: Int? = nil
) -> MCPResult
```

3. Use simple keyword/pattern extraction for action items and decisions (no external AI needed initially)

**Test Strategy**:
```swift
// Tests: ConversationSummarizerTests.swift
func testBriefSummaryGeneration()
func testDetailedSummaryGeneration()
func testActionItemExtraction()
func testDecisionExtraction()
func testSummaryLength()
```

**Verification**:
- Summaries capture key conversation points
- Different summary types produce distinct outputs
- Tool integrates with MCP server

### **Phase 4: Polish & Optimization (1-2 days)**
*Goal: Integration testing and MCP protocol compliance*

#### 4.1 Integration Testing
**Tasks**:
1. Create integration tests in existing test files:
   - Test full MCP JSON-RPC request/response cycles
   - Test tool chaining (using results from one tool in another)
   - Test error handling for invalid parameters
   - Test edge cases (empty results, malformed queries)

2. Manual testing scenarios:
   - Test with real Slack data if available
   - Test MCP client integration (Claude Desktop)
   - Verify all tools return properly formatted JSON

**Test Strategy**:
```swift
// Tests: IntegrationTests.swift
func testFullMCPWorkflow()
func testToolChaining()
func testErrorRecovery()
func testEdgeCaseHandling()
```

**Verification**:
- All tools pass integration tests
- MCP protocol compliance verified
- Error handling works properly

## Testing Strategy Overview

### **Unit Tests** (per component)
- Each service class has comprehensive unit tests
- All MCP tools have individual test suites
- Mock data for consistent testing

### **Integration Tests** (cross-component)
- MCP server JSON-RPC protocol compliance
- Database query accuracy
- Tool interaction workflows
- Error handling across boundaries

### **Manual Testing** (user scenarios)
- Common query patterns from design document
- Complex multi-step workflows
- MCP client integration (Claude Desktop)
- Real Slack data testing

## Success Criteria

### **Phase 1 Success**
- [ ] Slack database queries work with all filter types
- [ ] Search integration connects semantic and structured queries
- [ ] All unit tests pass

### **Phase 2 Success**
- [ ] `query_slack_structured` fully functional with all designed parameters
- [ ] `get_slack_channels` returns accurate channel information
- [ ] Enhanced `query_slack_hybrid` improves result quality
- [ ] All tools pass integration tests

### **Phase 3 Success**
- [ ] `get_conversation_summary` generates useful summaries
- [ ] Advanced features integrate smoothly with existing tools

### **Phase 4 Success**
- [ ] Comprehensive test suite passes
- [ ] MCP protocol compliance verified
- [ ] Ready for production use

## Risk Mitigation

### **Technical Risks**
- **Database performance**: Query optimization as needed
- **Integration issues**: Early integration testing, mock services

### **Implementation Risks**
- **Complexity creep**: Strict phase boundaries, incremental delivery
- **Test coverage gaps**: Test-first development

## Final Approved Implementation Plan Summary

### **Phase 1: Foundation Enhancement (1-2 days)**
✅ **Step 1.1**: Create `SlackQueryService.swift` with structured filtering methods  
✅ **Step 1.2**: Extend same file with search integration (no separate bridge file)

### **Phase 2: Core Query Tools (2-3 days)**  
✅ **Step 2.1**: Add `query_slack_structured` MCP tool with comprehensive filtering  
✅ **Step 2.2**: Add `get_slack_channels` MCP tool for channel discovery  
✅ **Step 2.3**: Enhance existing `searchConversations` with structured filters (hybrid)

### **Phase 3: Advanced Features (3-4 days)**
✅ **Step 3.1**: Add `get_conversation_summary` MCP tool with basic summarization  
~~Step 3.2~~: Skipped analytics tool

### **Phase 4: Polish & Optimization (1-2 days)**
✅ **Step 4.1**: Integration testing and MCP protocol compliance

## Next Steps

1. **Immediate**: Begin Phase 1, Step 1.1 implementation
2. **Per Step**: Run tests and verify functionality
3. **Per Phase**: Comprehensive testing and verification
4. **Final**: Integration with Claude Desktop for real-world testing

This plan provides a clear, testable path from the current implementation to the core designed query interface, with verification points at every step to ensure quality and functionality.