# Slunk MCP Server Query Interface Design

## Overview

The Slunk MCP server will provide a comprehensive query interface for historical Slack conversations, messages, and channels that combines semantic search capabilities with structured query operations. This design prioritizes both flexibility for complex queries and simplicity for LLM agents to understand and use effectively. All operations are performed on stored/archived Slack data rather than live connections.

## Core Query Tools

### 1. `query_slack_semantic`

**Purpose**: Natural language and semantic search across all Slack content

**Parameters**:
- `query` (string, required): Natural language query or search terms
- `scope` (enum, optional): `"messages"`, `"channels"`, `"conversations"`, `"all"` (default: `"all"`)
- `time_range` (object, optional): `{"from": "2024-01-01", "to": "2024-12-31"}` or `{"last": "7d"}` 
- `limit` (integer, optional): Maximum results to return (default: 20)
- `include_context` (boolean, optional): Include surrounding messages for context (default: false)

**Example Usage**:
```json
{
  "query": "bug reports about login issues",
  "scope": "messages",
  "time_range": {"last": "30d"},
  "limit": 10,
  "include_context": true
}
```

### 2. `query_slack_structured`

**Purpose**: Precise filtering and querying using structured parameters

**Parameters**:
- `filters` (object, required): Structured filter criteria
  - `channels` (array, optional): Channel names or IDs to search within
  - `users` (array, optional): Specific users to include/exclude
  - `message_types` (array, optional): `["text", "file", "thread_reply", "reaction"]`
  - `has_attachments` (boolean, optional): Filter for messages with files/images
  - `has_reactions` (boolean, optional): Filter for messages with reactions
  - `thread_replies_only` (boolean, optional): Only thread replies
  - `mentions_me` (boolean, optional): Messages that mention the querying user
- `time_range` (object, optional): Same as semantic query
- `sort_by` (enum, optional): `"timestamp"`, `"relevance"`, `"reactions"` (default: `"timestamp"`)
- `sort_order` (enum, optional): `"asc"`, `"desc"` (default: `"desc"`)
- `limit` (integer, optional): Maximum results (default: 20)

**Example Usage**:
```json
{
  "filters": {
    "channels": ["#engineering", "#bugs"],
    "users": ["john.doe", "jane.smith"],
    "has_attachments": true,
    "message_types": ["text", "file"]
  },
  "time_range": {"from": "2024-06-01", "to": "2024-06-30"},
  "sort_by": "reactions",
  "limit": 15
}
```

### 3. `query_slack_hybrid`

**Purpose**: Combines semantic search with structured filtering for maximum flexibility

**Parameters**:
- `semantic_query` (string, required): Natural language component
- `filters` (object, optional): Structured filters from `query_slack_structured`
- `semantic_weight` (float, optional): Weight of semantic vs structured results (0.0-1.0, default: 0.7)
- `time_range` (object, optional): Time filtering
- `limit` (integer, optional): Maximum results (default: 20)

**Example Usage**:
```json
{
  "semantic_query": "deployment issues and rollback procedures",
  "filters": {
    "channels": ["#devops", "#incidents"],
    "has_reactions": true
  },
  "semantic_weight": 0.8,
  "time_range": {"last": "14d"}
}
```

## Channel and Conversation Management Tools

### 4. `get_slack_channels`

**Purpose**: Retrieve and filter channel information from stored data

**Parameters**:
- `type` (enum, optional): `"public"`, `"private"`, `"dm"`, `"group"`, `"all"` (default: `"all"`)
- `member_count_min` (integer, optional): Minimum member count filter
- `include_archived` (boolean, optional): Include archived channels (default: false)
- `name_pattern` (string, optional): Regex pattern for channel names
- `last_activity_before` (string, optional): ISO date to filter channels by last message time

### 5. `get_conversation_summary`

**Purpose**: Get AI-generated summaries of conversations or threads

**Parameters**:
- `conversation_id` (string, required): Channel ID or thread timestamp
- `time_range` (object, optional): Specific time window to summarize
- `summary_type` (enum, optional): `"brief"`, `"detailed"`, `"action_items"`, `"decisions"` (default: `"brief"`)
- `max_length` (integer, optional): Maximum summary length in words

## Response Format Design

### Standard Response Structure
```json
{
  "results": [
    {
      "id": "message_unique_id",
      "type": "message|channel|conversation",
      "content": "actual message text or summary",
      "metadata": {
        "channel": "#channel-name",
        "channel_id": "C1234567890",
        "user": "username",
        "user_id": "U1234567890", 
        "timestamp": "2024-06-25T10:30:00Z",
        "thread_ts": "1234567890.123456",
        "reactions": [{"emoji": "👍", "count": 5}],
        "attachments": ["file1.pdf", "image.png"],
        "mentions": ["@user1", "@user2"]
      },
      "context": {
        "thread_context": "surrounding thread messages if requested",
        "conversation_context": "relevant conversation context",
        "relevance_score": 0.85
      }
    }
  ],
  "query_info": {
    "total_results": 47,
    "results_returned": 20,
    "query_time_ms": 234,
    "filters_applied": ["time_range", "channels"],
    "semantic_query_used": true
  },
  "suggestions": {
    "related_channels": ["#related-channel"],
    "related_users": ["@related-user"],
    "time_periods": ["Consider expanding to last 60 days"],
    "refinements": ["Try adding 'urgent' to your query"]
  }
}
```

## Advanced Features

### Query Templating
Pre-built query templates for common use cases:
- `template` parameter accepts: `"recent_mentions"`, `"my_threads"`, `"urgent_items"`, `"decisions_made"`, `"action_items"`, `"file_shares"`

### Contextual Intelligence
- Automatic detection of related conversations
- Thread relationship mapping
- User interaction patterns
- Channel activity correlation

### Export and Integration
- `export_results` tool for saving query results in various formats (CSV, JSON, Markdown)

## LLM Agent Usage Patterns

### Simple Queries
```
"Find recent bug reports" → query_slack_semantic with basic parameters
```

### Complex Analysis
```
"Analyze deployment issues from last month in engineering channels" → 
query_slack_hybrid with semantic + structured filters
```

### Historical Analysis
```
"Analyze security incident discussions from Q1" → 
Combination of structured queries with time range filtering
```

### Research Tasks
```
"Summarize decisions made about the new API design" → 
query_slack_semantic + get_conversation_summary
```

## Implementation Considerations

### Performance
- Use pagination for large result sets
- Provide query cost estimation


### Extensibility
- Plugin architecture for custom query processors
- Custom field indexing for organization-specific needs

This interface design prioritizes discoverability for LLM agents while maintaining the flexibility needed for sophisticated Slack data analysis and retrieval tasks.

## Data Model and Indexing Strategy

### Message Entity Structure
```json
{
  "message_id": "unique_identifier",
  "channel_id": "C1234567890",
  "user_id": "U1234567890", 
  "timestamp": "2024-06-25T10:30:00Z",
  "text": "raw message content",
  "text_processed": "processed for semantic search",
  "thread_ts": "parent_thread_timestamp",
  "reply_count": 5,
  "reactions": [{"name": "thumbsup", "count": 3, "users": ["U123", "U456"]}],
  "attachments": [
    {
      "type": "file|image|link",
      "url": "file_url",
      "title": "filename",
      "mimetype": "application/pdf"
    }
  ],
  "mentions": {
    "users": ["U789", "U012"],
    "channels": ["C345"],
    "special": ["@channel", "@here"]
  },
  "metadata": {
    "edited": true,
    "pinned": false,
    "starred": false,
    "importance_score": 0.75,
    "topic_tags": ["deployment", "bug", "urgent"]
  }
}
```

### Channel Entity Structure
```json
{
  "channel_id": "C1234567890",
  "name": "engineering",
  "display_name": "#engineering",
  "type": "public|private|dm|mpim",
  "topic": "Engineering discussions",
  "purpose": "Technical coordination",
  "member_count": 45,
  "is_archived": false,
  "created": "2024-01-15T09:00:00Z",
  "last_message_timestamp": "2024-06-25T16:45:00Z",
  "total_message_count": 15234
}
```

## Advanced Query Tools

### 6. `analyze_slack_trends`

**Purpose**: Identify patterns and trends in Slack activity

**Parameters**:
- `analysis_type` (enum, required): `"activity_patterns"`, `"topic_trends"`, `"user_engagement"`, `"sentiment_analysis"`
- `time_range` (object, required): Analysis period
- `scope` (object, optional): Channels, users, or topics to focus on
- `granularity` (enum, optional): `"hourly"`, `"daily"`, `"weekly"` (default: `"daily"`)

**Example Usage**:
```json
{
  "analysis_type": "topic_trends",
  "time_range": {"last": "30d"},
  "scope": {
    "channels": ["#engineering", "#product"],
    "topics": ["api", "performance", "security"]
  },
  "granularity": "weekly"
}
```

### 7. `query_slack_relationships`

**Purpose**: Explore relationships between users, channels, and topics

**Parameters**:
- `relationship_type` (enum, required): `"user_interactions"`, `"channel_overlap"`, `"topic_connections"`, `"influence_network"`
- `focus_entity` (object, required): The central entity to analyze relationships for
- `depth` (integer, optional): Degrees of separation to explore (default: 2)
- `min_interaction_threshold` (integer, optional): Minimum interactions to consider (default: 5)

**Example Usage**:
```json
{
  "relationship_type": "user_interactions",
  "focus_entity": {
    "type": "user",
    "id": "U1234567890"
  },
  "depth": 3,
  "min_interaction_threshold": 10
}
```


## Query Enhancement Features

### Intelligent Query Expansion
- **Auto-completion**: Suggest relevant channels, users, and time ranges
- **Synonym detection**: Automatically include related terms
- **Context awareness**: Use previous queries to improve suggestions
- **Typo correction**: Handle misspelled channel names and usernames

### Result Ranking and Relevance
```json
{
  "ranking_factors": {
    "semantic_similarity": 0.4,
    "recency": 0.2,
    "user_importance": 0.15,
    "channel_relevance": 0.15,
    "interaction_count": 0.1
  },
  "boost_conditions": {
    "pinned_messages": 1.5,
    "high_reaction_count": 1.3,
    "mentions_query_user": 1.2,
    "thread_starters": 1.1
  }
}
```

### Query Performance Optimization
- **Indexed fields**: Channel names, user names, message timestamps, reaction counts
- **Full-text search**: Message content with stemming and fuzzy matching
- **Vector search**: Semantic embeddings for natural language queries

## Error Handling and Edge Cases

### Robust Error Responses
```json
{
  "error": {
    "code": "INSUFFICIENT_PERMISSIONS",
    "message": "Cannot access private channel #secret-project",
    "details": {
      "restricted_channels": ["#secret-project"],
      "available_alternatives": ["#general-project"],
      "permission_required": "channel_member"
    },
    "suggestions": [
      "Request access to #secret-project",
      "Try searching in #general-project instead",
      "Use broader channel filters"
    ]
  }
}
```

### Graceful Degradation
- **Partial results**: Return available data when some sources fail
- **Fallback queries**: Automatic retry with relaxed parameters
- **Rate limit handling**: Queue and batch requests when limits are hit

## Integration Patterns for LLM Agents

### Conversation-Driven Queries
```
Agent: "What were the main issues discussed in engineering this week?"
→ query_slack_semantic + get_conversation_summary

Agent: "Who are the most active contributors to the API discussions?"
→ query_slack_structured + analyze_slack_trends

Agent: "Find all discussions about the new feature launch from last month"
→ query_slack_semantic with time range filters
```

### Multi-Step Analysis Workflows
```
1. query_slack_semantic("deployment problems")
2. analyze_slack_trends(focus on identified time periods)
3. query_slack_relationships(find key contributors)
4. get_conversation_summary(summarize solutions found)
```

### Contextual Follow-up Queries
```json
{
  "query_context": {
    "previous_query_id": "query_123",
    "conversation_thread": "deployment_investigation",
    "user_intent": "root_cause_analysis"
  },
  "follow_up_suggestions": [
    "Expand time range to include last month",
    "Include related channels like #devops",
    "Look for similar issues in other teams"
  ]
}
```


## Future Extensibility

### Plugin Architecture
```json
{
  "plugin_interface": {
    "custom_analyzers": "organization_sentiment_analyzer",
    "external_integrations": "jira_ticket_linker", 
    "custom_formatters": "executive_summary_formatter",
    "specialized_queries": "code_review_analyzer"
  }
}
```

### Machine Learning Integration
- **Custom embeddings**: Train organization-specific semantic models
- **Anomaly detection**: Identify unusual patterns in communication
- **Predictive analytics**: Forecast team communication needs
- **Auto-categorization**: Automatically tag and categorize conversations

This comprehensive query interface design provides LLM agents with powerful, intuitive tools for Slack data analysis while maintaining the flexibility to handle complex organizational communication patterns and compliance requirements.