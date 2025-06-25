# Slunk Production Documentation

## Overview

Slunk is a production-ready vector database system for managing and searching conversation snippets using semantic search, keyword matching, and temporal filtering. It integrates with Claude Desktop via the Model Context Protocol (MCP) to provide intelligent conversation memory.

## Architecture

### Core Components

1. **SQLiteVec Database**
   - Persistent storage in Application Support directory
   - Vector embeddings stored using SQLiteVec extension
   - Relational data stored using GRDB
   - WAL mode for concurrent access

2. **Natural Language Processing**
   - Apple's NLEmbedding for 512-dimensional sentence embeddings
   - NLTagger for keyword extraction and entity recognition
   - Natural language query parsing with intent detection

3. **MCP Server Integration**
   - JSON-RPC 2.0 over stdio transport
   - Three main tools: searchConversations, ingestText, getConversationStats
   - Sandboxed execution within macOS app

4. **Production Services**
   - Error handling with retry logic
   - Resource monitoring (memory, concurrency)
   - Comprehensive logging system
   - Database maintenance automation

## Features

### Semantic Search
- Vector similarity search using cosine distance
- Hybrid search combining semantic and keyword matching
- Natural language query understanding
- Temporal filtering ("yesterday", "last week", etc.)

### Data Management
- Automatic keyword extraction
- Entity recognition (people, places, organizations)
- Persistent storage across app launches
- Automatic data seeding for new installations

### Performance
- Query response time < 200ms
- Scales to 100,000+ conversations
- Database optimizations (WAL, indexing, caching)
- Memory-mapped I/O for faster access

### Production Features
- Comprehensive error handling
- Structured logging with rotation
- Configuration management
- Feature flags for gradual rollout
- Automatic database maintenance

## Usage

### Initialize the Service

```swift
let service = ProductionService.shared
await service.initialize()
```

### Search Conversations

```swift
let results = try await service.search(query: "Swift async patterns")
for result in results {
    print("\(result.summary.title) - Score: \(result.combinedScore)")
}
```

### Ingest New Content

```swift
let result = try await service.ingest(
    content: "Discussion about SwiftUI performance...",
    title: "SwiftUI Performance Tips",
    summary: "Key insights on optimizing SwiftUI",
    sender: "DevTeam"
)
```

### MCP Integration

The MCP server exposes three tools:

1. **searchConversations**
   ```json
   {
     "method": "searchConversations",
     "params": {
       "query": "Swift concurrency",
       "limit": 10
     }
   }
   ```

2. **ingestText**
   ```json
   {
     "method": "ingestText",
     "params": {
       "content": "Full conversation text...",
       "title": "Meeting Notes",
       "summary": "Key decisions from the meeting",
       "sender": "Alice"
     }
   }
   ```

3. **getConversationStats**
   ```json
   {
     "method": "getConversationStats",
     "params": {}
   }
   ```

## Configuration

### File Locations
- Database: `~/Library/Application Support/Slunk/slunk_conversations.db`
- Logs: `~/Library/Application Support/Slunk/Logs/`
- MCP Config: `claude-config.json`

### Performance Tuning
- Cache size: 64MB (configurable)
- Memory-mapped I/O: 256MB (configurable)
- Max concurrent operations: 50
- Query timeout: 30 seconds

### Feature Flags
```swift
FeatureFlags.isVectorSearchEnabled = true
FeatureFlags.isKeywordSearchEnabled = true
FeatureFlags.isAutoKeywordExtractionEnabled = true
FeatureFlags.isDatabaseOptimizationEnabled = true
```

## Error Handling

### Error Types
- `SlunkError.databaseInitializationFailed`: Database setup issues
- `SlunkError.ingestionFailed`: Content ingestion problems
- `SlunkError.queryFailed`: Search execution errors
- `SlunkError.embeddingGenerationFailed`: NLP processing issues
- `SlunkError.memoryPressureHigh`: System resource constraints

### Recovery Strategies
- Automatic retry with exponential backoff
- Input sanitization and validation
- Graceful degradation for non-critical features
- Comprehensive error logging

## Monitoring

### Logging
- Structured logging with categories
- Automatic log rotation (5 files, 10MB each)
- OS log integration for Console.app
- Performance metrics tracking

### Statistics
- Total conversations and embeddings
- Query and ingestion counts
- Database size monitoring
- Memory usage tracking

## Testing

### Unit Tests
- Model tests (TextSummary)
- Service tests (EmbeddingService, QueryEngine, etc.)
- Database schema tests

### Integration Tests
- End-to-end semantic search
- MCP server integration
- Production error scenarios
- Performance benchmarks

### Performance Tests
- Query performance (<200ms target)
- Scalability (100K+ items)
- Concurrent operations
- Memory usage

## Deployment

### Requirements
- macOS 15.5+
- Swift 5.9+
- ~100MB disk space for database
- App Sandbox entitlements

### Installation
1. Build with Xcode or `xcodebuild`
2. Configure MCP in Claude Desktop
3. App initializes database on first launch
4. Automatic data seeding for demos

## Maintenance

### Automatic Tasks
- Database VACUUM every 24 hours
- Log rotation when files exceed 10MB
- Memory pressure monitoring
- Index optimization

### Manual Tasks
- Monitor error logs for patterns
- Review performance metrics
- Update feature flags as needed
- Database backups (optional)

## Security

### Data Protection
- App Sandbox isolation
- Input sanitization for SQL injection prevention
- No network access except MCP communication
- Local storage only (no cloud sync)

### Privacy
- All data stored locally
- No telemetry or analytics
- User-controlled data lifecycle
- Clear data ownership

## Future Enhancements

### Planned Features
- Query result caching (framework in place)
- Advanced temporal queries
- Multi-language support
- Export/import functionality

### Performance Improvements
- Connection pooling (framework in place)
- Query plan optimization
- Incremental indexing
- Background processing

## Support

For issues or questions:
1. Check logs in `~/Library/Application Support/Slunk/Logs/`
2. Review error recovery suggestions
3. Verify database integrity
4. Check system resources

## License

This project is part of the Slunk MCP integration for Claude Desktop.