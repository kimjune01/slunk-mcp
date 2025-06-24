# Vector Database Expansion - TDD Implementation Plan

## 🎯 Overview

Transform the current vector store system using **Test-Driven Development** methodology to support:
- Frequent automated ingestion with temporal metadata
- Natural language queries with date range filtering
- Keyword matching combined with semantic search
- Data seeding with conversation snippets
- Persistent storage across application launches

## 🔄 TDD Workflow Reminder

For each step:
1. **🔴 RED**: Write failing tests first
2. **🟢 GREEN**: Write minimal code to pass tests
3. **🔄 REFACTOR**: Improve code while keeping tests green
4. **✅ COMMIT**: Commit changes with passing tests before next step

## 📋 TDD Implementation Steps

### **Step 4: Enhanced Data Model with Temporal Metadata**

#### **Tests to Write First:**
```swift
// Tests/Models/EnhancedTextSummaryTests.swift
func testEnhancedTextSummaryCreation() {
    // Should create TextSummary with temporal metadata
    // Should validate sender field
    // Should handle timestamp correctly
    // Should store and retrieve keywords array
    // Should generate proper temporal computed properties
}

func testTemporalProperties() {
    // Should calculate dayOfWeek correctly
    // Should format monthYear properly
    // Should generate relativeTime strings
    // Should handle timezone conversions
}

func testKeywordHandling() {
    // Should store keywords as array
    // Should validate keyword format
    // Should handle empty keywords gracefully
    // Should deduplicate keywords
}

func testSenderValidation() {
    // Should accept valid sender names
    // Should handle nil sender gracefully
    // Should reject empty/whitespace-only senders
    // Should normalize sender names
}

func testTimestampHandling() {
    // Should store precise timestamps
    // Should handle different date formats
    // Should maintain timezone information
    // Should sort by timestamp correctly
}
```

#### **Implementation Tasks:**
- Update `TextSummary.swift` with new fields
- Add temporal computed properties
- Implement keyword validation
- Add sender normalization
- Update encoding/decoding

#### **Commit Message:**
```
Step 4: Enhanced data model with temporal metadata

- ✅ Added sender, timestamp, keywords fields to TextSummary
- ✅ Implemented temporal computed properties (dayOfWeek, monthYear)
- ✅ Added keyword validation and deduplication
- ✅ Enhanced Codable support for new fields
- ✅ All tests passing (12/12)

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### **Step 5: Enhanced Database Schema with Temporal Indexing**

#### **Tests to Write First:**
```swift
// Tests/Database/EnhancedSQLiteVecSchemaTests.swift
func testEnhancedSchemaCreation() {
    // Should create enhanced text_summaries table
    // Should create temporal indexes
    // Should create keyword indexes
    // Should verify all columns exist with correct types
}

func testTemporalIndexes() {
    // Should create date_only index
    // Should create month_year index  
    // Should create day_of_week index
    // Should verify index performance
}

func testEnhancedInsert() {
    // Should insert TextSummary with temporal metadata
    // Should handle nil sender gracefully
    // Should store keywords as JSON
    // Should auto-generate temporal fields
}

func testTemporalQueries() {
    // Should query by date range efficiently
    // Should filter by month/year
    // Should filter by day of week
    // Should combine temporal and text filters
}

func testKeywordQueries() {
    // Should search by keywords using JSON queries
    // Should handle partial keyword matches
    // Should combine keyword and semantic search
    // Should rank by keyword relevance
}

func testSenderQueries() {
    // Should filter by sender efficiently
    // Should handle case-insensitive sender matching
    // Should support multiple sender filtering
    // Should combine with other filters
}
```

#### **Implementation Tasks:**
- Update database schema with new columns
- Add temporal indexes (date_only, month_year, day_of_week)
- Implement enhanced insert/query methods
- Add migration support for existing data
- Create keyword search functionality

#### **Commit Message:**
```
Step 5: Enhanced database schema with temporal indexing

- ✅ Updated SQLite schema with temporal metadata columns
- ✅ Added temporal indexes for efficient date/time queries
- ✅ Implemented keyword storage as JSON with indexing
- ✅ Added sender indexing for fast filtering
- ✅ Created database migration system
- ✅ All schema tests passing (15/15)

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### **Step 6: Persistent Storage Manager**

#### **Tests to Write First:**
```swift
// Tests/Database/PersistentStorageManagerTests.swift
func testDatabaseLocation() {
    // Should create database in Application Support directory
    // Should create directory structure if missing
    // Should return consistent path across calls
    // Should handle permissions correctly
}

func testDatabaseInitialization() {
    // Should initialize database with correct schema
    // Should handle first-time setup
    // Should verify all tables and indexes exist
    // Should not lose data on restart
}

func testSchemaMigration() {
    // Should detect schema version changes
    // Should migrate from old to new schema
    // Should preserve existing data during migration
    // Should handle migration failures gracefully
}

func testBackupRestore() {
    // Should create backup files
    // Should restore from backup successfully
    // Should verify data integrity after restore
    // Should handle corrupted backup files
}

func testPersistenceAcrossRestarts() {
    // Should persist data between app launches
    // Should maintain indexes after restart
    // Should preserve vector embeddings
    // Should handle concurrent access safely
}
```

#### **Implementation Tasks:**
- Create `PersistentStorageManager` class
- Implement Application Support directory setup
- Add schema versioning and migration
- Create backup/restore functionality
- Ensure data persistence across launches

#### **Commit Message:**
```
Step 6: Persistent storage manager with migrations

- ✅ Implemented PersistentStorageManager for app lifecycle
- ✅ Added Application Support directory database location
- ✅ Created schema versioning and migration system
- ✅ Implemented backup/restore functionality
- ✅ Verified data persistence across app restarts
- ✅ All persistence tests passing (18/18)

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### **Step 7: Automatic Keyword Extraction Service**

#### **Tests to Write First:**
```swift
// Tests/Services/KeywordExtractionServiceTests.swift
func testBasicKeywordExtraction() {
    // Should extract nouns and important terms
    // Should filter out stop words
    // Should handle different text lengths
    // Should return ranked keywords by importance
}

func testTFIDFScoring() {
    // Should calculate TF-IDF scores correctly
    // Should rank keywords by relevance
    // Should handle document frequency properly
    // Should normalize scores appropriately
}

func testNLTaggerIntegration() {
    // Should use NLTagger for named entity recognition
    // Should extract person, place, organization names
    // Should handle different languages
    // Should filter by tag types correctly
}

func testKeywordDeduplication() {
    // Should remove duplicate keywords
    // Should handle case variations
    // Should merge similar terms
    // Should maintain relevance rankings
}

func testPerformance() {
    // Should process large texts efficiently
    // Should handle batch processing
    // Should complete extraction in reasonable time
    // Should not block main thread
}

func testEdgeCases() {
    // Should handle empty text gracefully
    // Should process very short texts
    // Should handle special characters
    // Should work with emoji and unicode
}
```

#### **Implementation Tasks:**
- Create `KeywordExtractionService` class
- Integrate `NLTagger` for named entity recognition
- Implement TF-IDF scoring algorithm
- Add keyword deduplication and ranking
- Create batch processing capabilities

#### **Commit Message:**
```
Step 7: Automatic keyword extraction service

- ✅ Implemented KeywordExtractionService with NLTagger
- ✅ Added TF-IDF scoring for keyword relevance
- ✅ Created named entity recognition for persons/places
- ✅ Implemented keyword deduplication and ranking
- ✅ Added batch processing for efficient operation
- ✅ All keyword extraction tests passing (21/21)

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### **Step 8: High-Frequency Ingestion Service**

#### **Tests to Write First:**
```swift
// Tests/Services/IngestionServiceTests.swift
func testSingleItemIngestion() {
    // Should ingest single item successfully
    // Should generate embedding automatically
    // Should extract keywords automatically
    // Should store in database with metadata
}

func testBatchIngestion() {
    // Should process multiple items efficiently
    // Should handle batch size limits
    // Should maintain order when needed
    // Should report progress for large batches
}

func testAsyncQueueProcessing() {
    // Should queue items for background processing
    // Should process queue in order
    // Should handle queue overflow gracefully
    // Should support priority queuing
}

func testIngestionValidation() {
    // Should validate required fields
    // Should handle malformed input gracefully
    // Should sanitize content appropriately
    // Should reject duplicate content
}

func testErrorHandling() {
    // Should handle embedding generation failures
    // Should retry failed ingestions
    // Should log errors appropriately
    // Should not crash on invalid input
}

func testPerformanceRequirements() {
    // Should ingest > 1000 items/minute in batch mode
    // Should complete single ingestion < 100ms
    // Should handle concurrent ingestion safely
    // Should not leak memory during long runs
}

func testIngestionItem() {
    // Should create IngestionItem with all fields
    // Should validate timestamp formats
    // Should handle metadata dictionary
    // Should serialize/deserialize correctly
}
```

#### **Implementation Tasks:**
- Create `IngestionService` actor for thread safety
- Implement async queue for background processing
- Add batch processing with configurable sizes
- Create `IngestionItem` data structure
- Add validation and error handling
- Integrate with existing services

#### **Commit Message:**
```
Step 8: High-frequency ingestion service

- ✅ Implemented IngestionService actor with async queue
- ✅ Added batch processing for >1000 items/minute
- ✅ Created IngestionItem model with validation
- ✅ Integrated automatic keyword extraction
- ✅ Added error handling and retry logic
- ✅ Verified <100ms single item ingestion performance
- ✅ All ingestion tests passing (27/27)

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### **Step 9: Natural Language Query Parser**

#### **Tests to Write First:**
```swift
// Tests/Services/QueryParserTests.swift
func testBasicQueryParsing() {
    // Should parse "show me" queries
    // Should extract main topic/subject
    // Should identify action verbs (find, show, search)
    // Should handle different query formats
}

func testTemporalHintExtraction() {
    // Should recognize "last week", "yesterday"
    // Should parse "from January to March"
    // Should handle relative dates
    // Should convert to date ranges correctly
}

func testEntityExtraction() {
    // Should extract person names
    // Should identify places and organizations
    // Should recognize technical terms
    // Should maintain entity relationships
}

func testKeywordIdentification() {
    // Should identify important keywords
    // Should filter out stop words
    // Should handle compound terms
    // Should rank by importance
}

func testQueryIntent() {
    // Should classify query intent (search, filter, analyze)
    // Should determine result type expected
    // Should handle ambiguous queries
    // Should provide confidence scores
}

func testComplexQueries() {
    // Should parse "Swift conversations with Alice last week"
    // Should handle "planning meetings from June"
    // Should process "performance issues yesterday"
    // Should parse multiple filters in one query
}

func testEdgeCases() {
    // Should handle empty queries
    // Should process single-word queries
    // Should work with typos and variations
    // Should handle non-English terms
}
```

#### **Implementation Tasks:**
- Create `QueryParser` class with NLP capabilities
- Implement temporal hint recognition
- Add entity extraction using `NLTagger`
- Create query intent classification
- Add support for complex multi-filter queries

#### **Commit Message:**
```
Step 9: Natural language query parser

- ✅ Implemented QueryParser with NLP capabilities
- ✅ Added temporal hint extraction for date ranges
- ✅ Created entity recognition for persons/places/topics
- ✅ Implemented query intent classification
- ✅ Added support for complex multi-filter queries
- ✅ Handle queries like "Swift conversations with Alice last week"
- ✅ All query parsing tests passing (33/33)

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### **Step 10: Hybrid Query Engine**

#### **Tests to Write First:**
```swift
// Tests/Services/HybridQueryEngineTests.swift
func testSemanticSearch() {
    // Should perform vector similarity search
    // Should rank by semantic similarity
    // Should handle query embedding generation
    // Should return similarity scores
}

func testKeywordMatching() {
    // Should match exact keywords
    // Should handle partial keyword matches
    // Should weight keyword matches appropriately
    // Should combine with semantic scores
}

func testTemporalFiltering() {
    // Should filter by date ranges accurately
    // Should handle relative dates
    // Should support multiple temporal filters
    // Should optimize temporal queries
}

func testCombinedScoring() {
    // Should combine semantic + keyword + temporal scores
    // Should weight different factors appropriately
    // Should maintain score consistency
    // Should rank results correctly
}

func testComplexQueries() {
    // Should handle multi-filter queries
    // Should combine all search types
    // Should maintain performance with complexity
    // Should return ranked, relevant results
}

func testPerformanceRequirements() {
    // Should complete searches < 200ms
    // Should handle large datasets efficiently
    // Should scale with database size
    // Should optimize common query patterns
}

func testQueryResult() {
    // Should return complete QueryResult objects
    // Should include all score components
    // Should maintain result metadata
    // Should support result pagination
}
```

#### **Implementation Tasks:**
- Create `HybridQueryEngine` class
- Implement combined scoring algorithm
- Add semantic, keyword, and temporal search
- Create `QueryResult` model with scores
- Optimize for <200ms query performance

#### **Commit Message:**
```
Step 10: Hybrid query engine with combined scoring

- ✅ Implemented HybridQueryEngine with multi-modal search
- ✅ Added combined semantic + keyword + temporal scoring
- ✅ Created QueryResult model with score breakdowns
- ✅ Optimized for <200ms query performance
- ✅ Support complex queries with multiple filters
- ✅ Verified ranking accuracy across different query types
- ✅ All hybrid query tests passing (39/39)

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### **Step 11: Data Seeding System**

#### **Tests to Write First:**
```swift
// Tests/Services/DataSeederTests.swift
func testSeedDataLoading() {
    // Should load seed data from JSON/bundle
    // Should validate seed data format
    // Should handle missing seed files
    // Should parse all required fields
}

func testInitialDataSeeding() {
    // Should seed database on first run
    // Should not duplicate existing data
    // Should verify seeded data integrity
    // Should generate embeddings for seed data
}

func testSeedDataVariety() {
    // Should include conversation snippets
    // Should cover different categories
    // Should span various time periods
    // Should include different senders
}

func testSeedDataValidation() {
    // Should validate all required fields
    // Should check timestamp formats
    // Should verify keyword arrays
    // Should ensure content quality
}

func testSeedingPerformance() {
    // Should complete seeding quickly
    // Should handle large seed datasets
    // Should not block application startup
    // Should provide progress feedback
}

func testSkipExistingData() {
    // Should detect already seeded data
    // Should skip duplicate entries
    // Should handle partial seeding gracefully
    // Should resume interrupted seeding
}
```

#### **Implementation Tasks:**
- Create `DataSeeder` class
- Add sample conversation data
- Implement duplicate detection
- Add seeding progress tracking
- Integrate with app initialization

#### **Commit Message:**
```
Step 11: Data seeding system with sample conversations

- ✅ Implemented DataSeeder with JSON-based seed data
- ✅ Added sample conversations across categories/timeframes
- ✅ Created duplicate detection for existing data
- ✅ Added progress tracking for seeding operations
- ✅ Integrated with app initialization workflow
- ✅ Verified seed data quality and variety
- ✅ All data seeding tests passing (45/45)

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### **Step 12: Enhanced MCP Tools with Temporal Queries**

#### **Tests to Write First:**
```swift
// Tests/MCP/EnhancedMCPToolsTests.swift
func testSearchConversationsTool() {
    // Should accept natural language queries
    // Should handle date range parameters
    // Should filter by sender/keywords
    // Should return properly formatted results
}

func testTemporalQueryTools() {
    // Should handle getConversationsByDate
    // Should parse relative dates ("yesterday")
    // Should support absolute date ranges
    // Should combine with other filters
}

func testKeywordSearchTool() {
    // Should search by keyword arrays
    // Should combine keyword + semantic search
    // Should rank results appropriately
    // Should handle empty keyword lists
}

func testIngestTextTool() {
    // Should accept content with metadata
    // Should validate required parameters
    // Should return ingestion confirmation
    // Should handle batch ingestion requests
}

func testAnalyticsTools() {
    // Should provide conversation statistics
    // Should calculate temporal trends
    // Should summarize by category/sender
    // Should handle date range filtering
}

func testMCPProtocolCompliance() {
    // Should follow JSON-RPC 2.0 format
    // Should handle parameter validation
    // Should return proper error codes
    // Should maintain protocol consistency
}

func testErrorHandling() {
    // Should handle malformed requests
    // Should validate parameter types
    // Should return helpful error messages
    // Should not crash on invalid input
}
```

#### **Implementation Tasks:**
- Update `MCPServer.swift` with new tools
- Add `searchConversations` with natural language support
- Implement temporal query tools
- Add analytics and statistics tools
- Create batch ingestion endpoints

#### **Commit Message:**
```
Step 12: Enhanced MCP tools with temporal queries

- ✅ Added searchConversations tool with natural language support
- ✅ Implemented getConversationsByDate with relative dates
- ✅ Created findByKeywords with hybrid search
- ✅ Added ingestText and ingestBatch tools
- ✅ Implemented getConversationStats analytics
- ✅ Verified JSON-RPC 2.0 protocol compliance
- ✅ All MCP tools tests passing (51/51)

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### **Step 13: Performance Optimization and Caching**

#### **Tests to Write First:**
```swift
// Tests/Performance/CachingTests.swift
func testQueryCache() {
    // Should cache frequent query results
    // Should respect TTL for cache entries
    // Should invalidate cache when data changes
    // Should handle cache misses gracefully
}

func testIndexOptimization() {
    // Should verify index usage in queries
    // Should maintain index performance
    // Should optimize common query patterns
    // Should handle index rebuild operations
}

func testPerformanceBenchmarks() {
    // Should meet ingestion performance targets
    // Should achieve query response times
    // Should handle concurrent operations
    // Should scale with data volume
}

func testMemoryManagement() {
    // Should not leak memory during operations
    // Should handle large datasets efficiently
    // Should manage embedding cache appropriately
    // Should cleanup temporary objects
}

func testConcurrencyHandling() {
    // Should handle concurrent reads/writes
    // Should maintain data consistency
    // Should prevent race conditions
    // Should scale with concurrent users
}
```

#### **Implementation Tasks:**
- Create `QueryCache` actor for thread-safe caching
- Optimize database indexes for common queries
- Add performance monitoring and metrics
- Implement memory management optimizations
- Add concurrency safety measures

#### **Commit Message:**
```
Step 13: Performance optimization and caching layer

- ✅ Implemented QueryCache with TTL and invalidation
- ✅ Optimized database indexes for query performance
- ✅ Added performance monitoring and benchmarks
- ✅ Verified memory management and cleanup
- ✅ Enhanced concurrency safety for multi-user access
- ✅ Achieved performance targets: <100ms ingestion, <200ms queries
- ✅ All performance tests passing (57/57)

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### **Step 14: Integration Testing and End-to-End Workflows**

#### **Tests to Write First:**
```swift
// Tests/Integration/TemporalVectorStoreIntegrationTests.swift
func testCompleteIngestionWorkflow() {
    // Should ingest → extract keywords → generate embeddings → store
    // Should handle temporal metadata correctly
    // Should verify data persistence
    // Should confirm vector similarity integrity
}

func testCompleteQueryWorkflow() {
    // Should parse natural language → hybrid search → rank results
    // Should handle temporal filtering accurately
    // Should combine semantic and keyword scoring
    // Should return properly formatted results
}

func testMCPIntegrationWorkflow() {
    // Should accept MCP requests → process → return responses
    // Should handle all new MCP tools correctly
    // Should maintain protocol compliance
    // Should provide comprehensive error handling
}

func testDataPersistenceWorkflow() {
    // Should persist data across app restarts
    // Should maintain indexes and performance
    // Should handle migration scenarios
    // Should preserve vector embeddings
}

func testRealWorldQueries() {
    // Should handle "Swift conversations from last week"
    // Should process "planning meetings with Alice"
    // Should find "performance issues yesterday"
    // Should support complex multi-filter scenarios
}

func testPerformanceUnderLoad() {
    // Should handle 1000+ concurrent ingestions
    // Should maintain query performance with large datasets
    // Should scale gracefully with data growth
    // Should not degrade over extended operations
}
```

#### **Implementation Tasks:**
- Create comprehensive end-to-end tests
- Test real-world query scenarios
- Verify performance under load
- Ensure data integrity across workflows
- Test MCP protocol integration

#### **Commit Message:**
```
Step 14: Integration testing and end-to-end workflows

- ✅ Created comprehensive end-to-end workflow tests
- ✅ Verified real-world query scenarios working correctly
- ✅ Tested performance under load (1000+ items)
- ✅ Confirmed data persistence across app lifecycle
- ✅ Validated MCP protocol integration end-to-end
- ✅ All integration tests passing (63/63)

Complete temporal vector store system ready for production! 🎉

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

## 🏁 Final System Capabilities

After completing all TDD steps, the system will support:

### **Natural Language Queries**
- *"Show me Swift conversations from last week"*
- *"Find planning discussions with Alice from June"*
- *"What did the support team say about performance yesterday?"*

### **High-Performance Ingestion**
- \>1000 items/minute batch processing
- <100ms single item ingestion
- Automatic keyword extraction
- Real-time embedding generation

### **Persistent Temporal Search**
- Semantic similarity search
- Keyword matching with TF-IDF
- Date range filtering
- Combined relevance scoring

### **Production Features**
- Database migrations
- Backup/restore
- Caching layer
- Performance monitoring
- Comprehensive error handling

## 📊 Success Metrics

Each step will be committed only when **all tests pass** and performance requirements are met:

- **Test Coverage**: >95% for all components
- **Performance**: <100ms ingestion, <200ms queries
- **Reliability**: Zero data loss, graceful error handling
- **Scalability**: Handles 100k+ summaries efficiently

This TDD approach ensures a robust, well-tested, production-ready temporal vector store system! 🚀