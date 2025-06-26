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

## Critical Analysis & Improved Strategy

### **🚨 Interface Design Issues Identified**
1. **Tool Confusion**: Multiple similar tools (structured/semantic/hybrid) create decision paralysis
2. **Parameter Overload**: Too many optional parameters overwhelm users and agents
3. **Real User Disconnect**: Users want to "find information", not choose query types
4. **Implementation Risk**: Building 3 complex tools simultaneously increases failure risk

### **🎯 Improved Interface Design**
**Leveraging vector database for powerful semantic + structured search:**
- `searchSlackMessages()` - hybrid semantic/structured search with SQLiteVec
- `getSlackChannels()` - channel discovery with filters
- `summarizeConversation()` - focused conversation analysis
- `findRelatedConversations()` - semantic similarity discovery (Phase 3 bonus)

### **📋 Success-Focused Implementation Strategy**

#### **👤 USER REVIEW POINTS** 
**You will be pulled in for review and approval at these critical junctions:**

1. **🔍 After Phase 1**: Review basic query functionality with real Slack data
2. **🛠️ After Phase 2.1**: Test unified search tool with sample agent queries  
3. **📊 After Phase 2.2**: Validate channel discovery meets real use cases
4. **✅ After Phase 3**: Final review before production deployment

### **Phase 1: Foundation + Proof of Concept (1-2 days)**
*Goal: Build structured query infrastructure with NO natural language processing*

#### 1.1 Slack Database Query Layer
**File**: `slunk-swift/slunk-swift/Database/SlackQueryService.swift` (new)

**Implementation Steps**:
1. Create `SlackQueryService` class with contextual search methods:
   - `searchBySemantic(embedding: [Float], minSimilarity: Float)` - vector search
   - `filterByChannels(channels: [String])`
   - `filterByUsers(users: [String])`
   - `filterByMessageTypes(types: [MessageType])`
   - `filterByTimeRange(from: Date, to: Date)`
   - `filterByReactions(hasReactions: Bool)`
   - `filterByAttachments(hasAttachments: Bool)`

2. **Contextual Embedding Enhancement**:
   - `buildThreadContext(message: SlackMessage)` - include parent/thread messages
   - `createConversationChunks(messages: [SlackMessage])` - group related messages
   - `enhanceMessageForEmbedding(message: SlackMessage)` - add channel/thread context

3. SQLiteVec integration:
   - Store both original and contextual embeddings
   - Use enhanced embeddings for semantic search
   - Support conversation-level and message-level search

**Test Strategy**:
```swift
// Tests: SlackQueryServiceTests.swift
func testSemanticSearch()
func testThreadContextBuilding()
func testConversationChunking()
func testContextualEmbeddings()
func testChannelFiltering()
func testUserFiltering() 
func testSemanticWithFilters()
func testShortMessageContext()
```

**Verification**:
- Thread context improves short message relevance
- Conversation chunks group related messages correctly
- Contextual embeddings outperform raw message embeddings
- Semantic search returns meaningful results for emoji/short responses

#### 1.2 Contextual Message Processing
**File**: `slunk-swift/slunk-swift/Services/MessageContextualizer.swift` (new)

**Implementation Steps**:
1. **Thread Context Enhancement**:
   ```swift
   func enhanceWithThreadContext(message: SlackMessage) -> String {
       guard let threadId = message.threadId else { return message.text }
       
       let threadMessages = getThreadMessages(threadId)
       let parentMessage = threadMessages.first?.text ?? ""
       let recentContext = threadMessages.suffix(3).map(\.text).joined(separator: " ")
       
       return """
       Thread context: \(parentMessage)
       Recent: \(recentContext)
       Current: \(message.text)
       Channel: \(message.channelTopic)
       """
   }
   ```

2. **Conversation Chunking**:
   ```swift
   func createConversationChunks(messages: [SlackMessage]) -> [ConversationChunk] {
       // Group messages by:
       // - Time proximity (within 10 minutes)
       // - Topic similarity (using keywords)
       // - User interaction patterns
       // - Thread relationships
   }
   
   struct ConversationChunk {
       let id: String
       let topic: String          // "API deployment discussion"
       let messages: [SlackMessage]
       let summary: String        // Generated summary for embedding
       let timeRange: DateRange
       let participants: [String]
   }
   ```

3. **Enhanced Embedding Pipeline**:
   - Process messages through context enhancement
   - Generate embeddings for both individual messages and chunks
   - Store multiple embedding types in SQLiteVec

#### 1.3 Query Combination and Ranking
**File**: Extend `slunk-swift/slunk-swift/Database/SlackQueryService.swift` (same file)

**Implementation Steps**:
1. Add hybrid query methods:
   - `executeHybridSearch(semantic: SemanticQuery?, filters: SearchFilters, mode: SearchMode)`
   - `combineResults(messageResults: [Result], chunkResults: [Result], mode: SearchMode)`
   - `rankByRelevance(results: [Result], semanticScores: [Float]?)`
   - `addMessageContext(messages: [Message], includeContext: Bool)`

2. Search modes with contextual support:
   - `semantic`: Search both contextual messages and conversation chunks
   - `structured`: Traditional filtering with context awareness
   - `hybrid`: Intelligent combination with context weighting

**Test Strategy**:
```swift
// Tests: MessageContextualizerTests.swift
func testThreadContextGeneration()
func testConversationChunkCreation()
func testShortMessageEnhancement()
func testContextualEmbeddingQuality()
func testChunkVsMessageSearch()
```

**Verification**:
- Thread context significantly improves short message search
- Conversation chunks capture related discussion topics
- Contextual embeddings outperform raw message embeddings
- Search works at both message and conversation levels

### **Phase 2: MCP Tools Implementation (2-3 days)**
*Goal: Build structured MCP tools that agents can use directly*

#### 2.1 `searchSlackMessages` - Hybrid Semantic/Structured Search Tool ⭐
**File**: `slunk-swift/slunk-swift/MCPServer.swift` (extend)

**Implementation Steps**:
1. **Replace existing `searchConversations`** with powerful hybrid tool:
```swift
@mcp.tool
func searchSlackMessages(
    // Semantic search options
    semanticQuery: String? = nil,      // "deployment issues and rollbacks"
    similarToMessageId: String? = nil, // Find messages similar to this one
    
    // Structured filters (applied on top)
    channels: [String]? = nil,         // ["engineering", "bugs"]
    users: [String]? = nil,            // ["john.doe", "jane.smith"]
    timeRange: TimeRange? = nil,       // {from: "2024-01-15", to: "2024-01-22"}
    messageTypes: [String]? = nil,     // ["text", "thread_reply", "file_share"]
    hasAttachments: Bool? = nil,
    hasReactions: Bool? = nil,
    
    // Search control
    searchMode: String = "hybrid",      // "semantic", "structured", "hybrid"
    minSimilarity: Float = 0.7,        // Similarity threshold (0-1)
    includeContext: Bool = false,      // include surrounding messages
    sortBy: String = "relevance",      // "relevance", "timestamp", "reactions"
    limit: Int = 20
) -> SlackSearchResult
```

2. **Contextual Hybrid Search Implementation**:
   - When `semanticQuery`: Generate embedding → search contextual messages AND conversation chunks
   - When `similarToMessageId`: Get contextual embedding → find similar discussions/replies
   - Apply structured filters on top of semantic results
   - Intelligent ranking combining context relevance with traditional scores

3. **Enhanced Response Format with Context**:
```json
{
  "results": [
    {
      "message_id": "1234567890.123456",
      "channel": "#engineering",
      "user": "john.doe",
      "timestamp": "2024-01-20T10:30:00Z",
      "text": "👍",
      "contextual_meaning": "Approval of API deployment proposal",
      "thread_context": {
        "parent_message": "Should we deploy the API changes today?",
        "thread_summary": "Team discussing API deployment timing and readiness"
      },
      "similarity_score": 0.92,     // contextual similarity score
      "relevance_score": 0.95,      // combined score
      "matched_concepts": ["deployment", "approval", "API"],
      "result_type": "contextual_message",  // or "conversation_chunk"
      "context": {
        "before": [...],  // if includeContext=true
        "after": [...]
      }
    }
  ],
  "conversation_chunks": [
    {
      "chunk_id": "conv_123",
      "topic": "API deployment discussion",
      "message_count": 8,
      "participants": ["john.doe", "jane.smith"],
      "time_range": {"start": "...", "end": "..."},
      "summary": "Team discussed API deployment timing, ran tests, and approved for deployment",
      "key_messages": ["1234567890.123456", "1234567890.234567"]
    }
  ],
  "metadata": {
    "total_results": 47,
    "contextual_matches": 32,     // results improved by context
    "chunk_matches": 15,          // conversation-level matches
    "search_type": "hybrid",
    "context_enhancement": true
  }
}
```

**Test Strategy**:
```swift
// Tests: ContextualSearchTests.swift  
func testContextualSemanticSearch()
func testShortMessageContextualMatching()
func testConversationChunkSearch()
func testThreadContextSearch()
func testHybridContextualMode()
func testSimilarityWithContext()
func testContextualInsights()
func testEmojiAndShortResponseSearch()
```

**🔍 USER REVIEW CHECKPOINT 1**:
- Test that "👍" in deployment thread matches "deployment approval"
- Validate conversation chunks group related discussions
- Confirm contextual embeddings dramatically improve short message search
- Verify thread context provides meaningful semantic understanding
- Approve contextual approach before proceeding to channels tool

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

**📊 USER REVIEW CHECKPOINT 2**:
- Test channel discovery with real workspace
- Validate filtering options meet actual needs
- Verify response format supports common workflows
- Approve channel tool before proceeding

### **Phase 3: Advanced Semantic Features (2-3 days)**
*Goal: Add conversation analysis and semantic discovery*

#### 3.1 `summarizeConversation` - Structured Conversation Analysis
**Files**: 
- `slunk-swift/slunk-swift/Services/ConversationSummarizer.swift` (new)
- `slunk-swift/slunk-swift/MCPServer.swift` (extend)

**Implementation Steps**:
1. **Focused Analysis Tool**:
```swift
@mcp.tool
func summarizeConversation(
    channelId: String,                // channel ID (required)
    timeRange: TimeRange? = nil,      // specific time window
    focusKeywords: [String]? = nil,   // focus summary on specific topics
    summaryType: String = "brief",    // "brief", "action_items", "key_points"
    maxPoints: Int = 10               // max items to extract
) -> ConversationSummary
```

2. **Pattern-Based Extraction** (no AI/NLP needed):
   - Extract messages matching action patterns ("TODO", "will do", "assigned to")
   - Find decision patterns ("decided", "agreed", "resolved") 
   - Count message frequency by participant
   - Group related messages by time proximity

3. **Structured Output**:
```json
{
  "channel_id": "C1234567890",
  "time_range": {"from": "2024-01-20T00:00:00Z", "to": "2024-01-20T23:59:59Z"},
  "summary": {
    "total_messages": 156,
    "participants": [
      {"user": "john.doe", "message_count": 45},
      {"user": "jane.smith", "message_count": 38}
    ],
    "key_points": [
      "API authentication bug identified in auth module",
      "Deployment scheduled for Friday 2pm"
    ],
    "action_items": [
      {"text": "TODO: Fix auth module bug", "user": "john.doe", "timestamp": "..."}
    ],
    "decisions": [
      {"text": "Agreed to use OAuth2 for authentication", "timestamp": "..."}
    ]
  }
}
```

**Test Strategy**:
```swift
// Tests: ConversationSummarizerTests.swift
func testBasicSummaryGeneration()
func testActionItemExtraction()
func testKeyPointExtraction()
func testParticipantIdentification()
```

#### 3.2 `findRelatedConversations` - Semantic Discovery Tool (Bonus)
**File**: `slunk-swift/slunk-swift/MCPServer.swift` (extend)

**Implementation Steps**:
1. **Semantic similarity discovery**:
```swift
@mcp.tool
func findRelatedConversations(
    referenceMessages: [String],        // Message IDs to use as reference
    conceptExpansion: Bool = true,      // Expand search to related concepts
    channels: [String]? = nil,          // Optional channel filter
    timeRange: TimeRange? = nil,
    minSimilarity: Float = 0.75,
    limit: Int = 10
) -> RelatedConversationsResult
```

2. **Implementation using vectors**:
   - Average embeddings of reference messages
   - Find similar message clusters
   - Group by conversation threads
   - Return related discussions across channels

**✅ USER REVIEW CHECKPOINT 3**:
- Test summarization with real Slack conversations
- Validate semantic discovery finds truly related content
- Confirm tools integrate well together
- Final approval for production deployment

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

### **Success Criteria by Phase**

#### **Phase 1 Success** ✅
- [ ] **USER REVIEW CHECKPOINT**: Query infrastructure validated with real Slack data
- [ ] Database filtering works for all parameter types
- [ ] Search integration handles semantic + structured queries
- [ ] All unit tests pass

#### **Phase 2 Success** ✅  
- [ ] **USER REVIEW CHECKPOINT 1**: `searchSlackMessages` tool tested with agent-generated parameters
- [ ] **USER REVIEW CHECKPOINT 2**: Channel discovery validated with real workspace
- [ ] Structured search produces accurate results without NLP
- [ ] Response format is clear and predictable
- [ ] All parameter combinations work correctly

#### **Phase 3 Success** ✅
- [ ] **USER REVIEW CHECKPOINT 3**: Conversation summarization tested with real data
- [ ] Summary quality meets user expectations
- [ ] Tool integrates seamlessly with search workflow
- [ ] **FINAL APPROVAL** for production deployment

#### **Phase 4 Success** ✅
- [ ] All integration tests pass
- [ ] MCP protocol compliance verified
- [ ] Documentation complete
- [ ] Ready for production use with user confidence

## Risk Mitigation

### **Technical Risks**
- **Database performance**: Query optimization as needed
- **Integration issues**: Early integration testing, mock services

### **Implementation Risks**
- **Complexity creep**: Strict phase boundaries, incremental delivery
- **Test coverage gaps**: Test-first development

## 🎯 Revised Implementation Plan Summary

### **Key Improvements Made**
- **Leverages Vector Database**: Full semantic search using SQLiteVec embeddings
- **Hybrid Approach**: Combines power of semantic + precision of structured search
- **Agent-Friendly**: Clear parameters with multiple search modes
- **Risk Reduction**: Added 4 critical user review checkpoints
- **Success-Focused**: Early validation with real data and testing

### **👤 USER REVIEW SCHEDULE**
1. **After Phase 1**: Validate structured query infrastructure with real Slack data
2. **After Phase 2.1**: Test search tool with agent-generated parameters
3. **After Phase 2.2**: Verify channel discovery meets real workspace needs
4. **After Phase 3**: Final approval before production deployment

### **📅 Revised Timeline**
- **Phase 1**: Structured Query Foundation (1-2 days) → **USER REVIEW 1**
- **Phase 2**: MCP Tools Implementation (2-3 days) → **USER REVIEWS 2 & 3** 
- **Phase 3**: Conversation Summarization (2-3 days) → **FINAL APPROVAL**
- **Phase 4**: Polish & Integration Testing (1-2 days)

### **🔧 Final Tool Set (Contextual Semantic + Structured)**
1. **`searchSlackMessages()`** - Contextual hybrid search with thread/conversation awareness
2. **`getSlackChannels()`** - Channel discovery with filters
3. **`summarizeConversation()`** - Pattern-based conversation analysis
4. **`findRelatedConversations()`** - Contextual semantic similarity discovery (bonus)

## Next Steps

1. **Immediate**: Begin Phase 1 with basic query infrastructure
2. **Critical**: Stop at each USER REVIEW checkpoint for validation
3. **Iterative**: Refine based on real usage feedback
4. **Success Metric**: User approval at each checkpoint before proceeding

### **🚀 Why This Contextual Approach Solves Key Problems**

**Solves the Short Message Problem:**
- "👍" in deployment thread → "deployment approval confirmation"
- "LGTM" in code review → "code review approval"
- "🚨" in incident channel → "urgent incident alert"

**Provides Conversation-Level Discovery:**
- Search for "API issues" → finds entire discussion threads
- Not just individual mentions, but complete conversations
- Groups related messages across time

**For Agents (like me):**
- Can find meaningful responses to emoji queries
- Thread context makes semantic search actually useful
- Conversation chunks provide better similarity matching
- Much higher quality results for semantic queries

**For Implementation:**
- Builds on existing SQLiteVec infrastructure
- Enhances current embeddings rather than replacing
- Clear separation between contextual and raw search
- Testable improvements (before/after context quality)

**For Users:**
- "Find approvals" actually finds approval emojis in context
- Short response search finally works meaningfully
- Conversation discovery vs just message fragments
- Dramatically better semantic search quality

**Contextual Search Examples:**

```swift
// Find approvals (now works with emoji!)
searchSlackMessages(
    semanticQuery: "approval confirmation agreed",
    searchMode: "semantic"  // Finds "👍", "LGTM", "approved", etc. in context
)

// Discover related conversations
searchSlackMessages(
    semanticQuery: "API deployment discussions",
    searchMode: "hybrid"    // Returns conversation chunks about API deployment
)

// Find similar responses to a specific approval
searchSlackMessages(
    similarToMessageId: "msg_123_thumbs_up",  // contextual embedding
    channels: ["engineering"]
)

// Structured search still works exactly the same
searchSlackMessages(
    channels: ["api"],
    users: ["john.doe"],
    timeRange: TimeRange(last: "1d"),
    searchMode: "structured"
)
```

This contextual approach transforms semantic search from "interesting but unreliable" to "actually useful for real Slack queries" while maintaining all existing structured search capabilities.