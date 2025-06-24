# Vector Database Expansion Plan

## 🎯 Overview

Expand the current vector store system to support:
- **Frequent automated ingestion** with temporal metadata
- **Natural language queries** with date range filtering
- **Keyword matching** combined with semantic search
- **Data seeding** with natural language snippets
- **Persistent storage** across application launches
- **Metadata-rich queries** (date, sender, keywords)

## 📊 Current State

✅ **Completed (Steps 1-3)**:
- TextSummary model with validation
- EmbeddingService with 512-dimensional vectors
- SQLiteVecSchema with similarity search
- Working round-trip integration tests

## 🔄 New Requirements Analysis

### **Frequent Ingestion Module**
- High-frequency data ingestion (potentially real-time)
- Batch processing capabilities
- Temporal metadata tracking
- Efficient indexing for time-based queries

### **Enhanced Query Capabilities**
- **Hybrid search**: Semantic similarity + keyword matching + date filtering
- **Natural language queries**: "Show me conversations about Swift from last week"
- **Temporal filtering**: Date ranges, relative dates ("yesterday", "last month")
- **Metadata filtering**: Sender, source, category combinations

### **Data Persistence & Seeding**
- Persistent SQLite database file (not in-memory)
- Initial data seeding with sample conversations/snippets
- Migration system for schema updates
- Data backup/restore capabilities

## 🏗️ Implementation Plan

### **Step 4: Enhanced Data Model with Temporal Metadata**

#### **Updated TextSummary Model**
```swift
struct TextSummary: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let content: String
    let summary: String
    
    // Enhanced metadata
    let sender: String?                    // NEW: Message sender/author
    let timestamp: Date                    // NEW: When content was created
    let source: String?                    // NEW: Where content came from
    let keywords: [String]                 // NEW: Extracted keywords
    let category: String?
    let tags: [String]?
    let sourceURL: String?
    
    // Computed fields
    let wordCount: Int
    let summaryWordCount: Int
    let createdAt: Date                    // When stored in DB
    let updatedAt: Date
    
    // NEW: Temporal query helpers
    var dayOfWeek: String { /* ... */ }
    var monthYear: String { /* ... */ }
    var relativeTime: String { /* ... */ }
}
```

#### **Enhanced Database Schema**
```sql
-- Main relational table (GRDB)
CREATE TABLE text_summaries (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    summary TEXT NOT NULL,
    
    -- Enhanced metadata
    sender TEXT,
    timestamp DATETIME NOT NULL,
    source TEXT,
    keywords TEXT, -- JSON array
    category TEXT,
    tags TEXT, -- JSON array
    source_url TEXT,
    
    -- Computed fields
    word_count INTEGER,
    summary_word_count INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Temporal indexing
    date_only DATE GENERATED ALWAYS AS (DATE(timestamp)) STORED,
    month_year TEXT GENERATED ALWAYS AS (strftime('%Y-%m', timestamp)) STORED,
    day_of_week INTEGER GENERATED ALWAYS AS (strftime('%w', timestamp)) STORED
);

-- Indexes for efficient querying
CREATE INDEX idx_summaries_timestamp ON text_summaries(timestamp);
CREATE INDEX idx_summaries_date_only ON text_summaries(date_only);
CREATE INDEX idx_summaries_sender ON text_summaries(sender);
CREATE INDEX idx_summaries_source ON text_summaries(source);
CREATE INDEX idx_summaries_category ON text_summaries(category);
CREATE INDEX idx_summaries_keywords ON text_summaries(keywords);

-- Vector table (SQLiteVec) - unchanged
CREATE VIRTUAL TABLE summary_embeddings USING vec0(
    embedding float[512],
    summary_id text
);
```

### **Step 5: Frequent Ingestion Module**

#### **IngestionService**
```swift
actor IngestionService {
    private let vectorStore: VectorStoreManager
    private let embeddingService: EmbeddingService
    private let queue: AsyncChannel<IngestionItem>
    
    // High-frequency ingestion
    func ingest(_ item: IngestionItem) async throws
    func ingestBatch(_ items: [IngestionItem]) async throws
    
    // Background processing
    func startBackgroundProcessing()
    func stopBackgroundProcessing()
    
    // Keyword extraction
    func extractKeywords(from text: String) -> [String]
}

struct IngestionItem {
    let content: String
    let sender: String?
    let timestamp: Date
    let source: String?
    let metadata: [String: Any]?
}
```

#### **Automatic Keyword Extraction**
- Use `NLTagger` for keyword extraction
- TF-IDF scoring for important terms
- Category classification using `NLClassifier`

### **Step 6: Enhanced Query System**

#### **HybridQueryEngine**
```swift
struct HybridQuery {
    let naturalLanguageQuery: String
    let dateRange: DateRange?
    let keywords: [String]?
    let sender: String?
    let source: String?
    let category: String?
    let limit: Int
    let minSimilarity: Float?
}

struct DateRange {
    let start: Date?
    let end: Date?
    
    // Convenience initializers
    static func lastWeek() -> DateRange
    static func lastMonth() -> DateRange
    static func yesterday() -> DateRange
    static func custom(from: Date, to: Date) -> DateRange
}

struct QueryResult {
    let summary: TextSummary
    let similarity: Float
    let matchedKeywords: [String]
    let relevanceScore: Float // Combined similarity + keyword + temporal
}

class HybridQueryEngine {
    func search(_ query: HybridQuery) async throws -> [QueryResult]
    private func combineScores(similarity: Float, keywordMatch: Float, temporal: Float) -> Float
}
```

#### **Natural Language Query Parsing**
```swift
class QueryParser {
    func parse(_ query: String) -> ParsedQuery
}

struct ParsedQuery {
    let intent: String                    // "find", "show", "search"
    let topic: String                     // extracted main topic
    let temporalHints: [String]          // "last week", "yesterday"
    let entities: [String]               // people, places, things
    let keywords: [String]               // important terms
}
```

### **Step 7: Persistent Storage & Configuration**

#### **Database Location**
```swift
class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var databaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                  in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Slunk")
        try! FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("vector_store.db")
    }
    
    func initializePersistentDatabase() async throws
    func migrateSchema(from oldVersion: Int, to newVersion: Int) async throws
    func backupDatabase() throws -> URL
    func restoreDatabase(from backupURL: URL) throws
}
```

#### **Data Seeding System**
```swift
class DataSeeder {
    func seedInitialData() async throws
    private func loadSeedData() -> [SeedItem]
}

struct SeedItem {
    let content: String
    let summary: String
    let sender: String
    let timestamp: Date
    let source: String
    let category: String
    let keywords: [String]
}
```

### **Step 8: Enhanced MCP Tools**

#### **New MCP Tools**
```swift
// Enhanced search with hybrid capabilities
func searchConversations(
    query: String,
    dateRange: String? = nil,     // "last week", "2024-01-01:2024-01-31"
    sender: String? = nil,
    keywords: [String]? = nil,
    limit: Int = 10
) -> [QueryResult]

// Temporal queries
func getConversationsByDate(
    date: String,                 // "2024-01-15" or "yesterday"
    sender: String? = nil
) -> [TextSummary]

// Keyword-based queries
func findByKeywords(
    keywords: [String],
    dateRange: String? = nil
) -> [TextSummary]

// Analytics
func getConversationStats(
    dateRange: String? = nil
) -> ConversationStats

// Data management
func ingestText(
    content: String,
    sender: String? = nil,
    timestamp: String? = nil,     // ISO 8601 or relative
    source: String? = nil,
    keywords: [String]? = nil
) -> String // Returns ID

// Batch ingestion
func ingestBatch(
    items: [IngestionRequest]
) -> BatchResult
```

### **Step 9: Performance Optimizations**

#### **Indexing Strategy**
- **Temporal indexes**: Date, month, day-of-week
- **Text indexes**: FTS5 for keyword search
- **Composite indexes**: Common query patterns
- **Vector indexes**: SQLiteVec automatic optimization

#### **Caching Layer**
```swift
actor QueryCache {
    private var cache: [String: (result: [QueryResult], timestamp: Date)] = [:]
    private let ttl: TimeInterval = 300 // 5 minutes
    
    func get(for query: String) -> [QueryResult]?
    func set(_ result: [QueryResult], for query: String)
    func invalidate(pattern: String? = nil)
}
```

#### **Background Processing**
- Async ingestion queue
- Batch embedding generation
- Periodic index optimization
- Automatic cleanup of old data

### **Step 10: Sample Seed Data**

#### **Conversation Snippets**
```json
[
  {
    "content": "We discussed the new Swift async/await features and how they improve code readability.",
    "summary": "Discussion about Swift async/await improvements",
    "sender": "Alice",
    "timestamp": "2024-06-20T14:30:00Z",
    "source": "Slack",
    "category": "Programming",
    "keywords": ["swift", "async", "await", "programming"]
  },
  {
    "content": "Meeting notes from the quarterly planning session covering Q3 goals and team objectives.",
    "summary": "Q3 planning session notes and team objectives",
    "sender": "Bob",
    "timestamp": "2024-06-19T10:00:00Z",
    "source": "Teams",
    "category": "Planning",
    "keywords": ["planning", "quarterly", "goals", "objectives"]
  },
  {
    "content": "Customer feedback on the mobile app performance issues and suggested improvements.",
    "summary": "Customer feedback on mobile app performance",
    "sender": "Support Team",
    "timestamp": "2024-06-18T16:45:00Z",
    "source": "Zendesk",
    "category": "Feedback",
    "keywords": ["mobile", "performance", "customer", "feedback"]
  }
]
```

## 🔄 Migration Strategy

### **Phase 1: Data Model Enhancement**
1. Update TextSummary model with temporal metadata
2. Create database migration system
3. Update existing tests

### **Phase 2: Enhanced Storage**
1. Implement persistent database storage
2. Add temporal indexing
3. Create data seeding system

### **Phase 3: Ingestion Module**
1. Build IngestionService with queue
2. Add keyword extraction
3. Implement batch processing

### **Phase 4: Hybrid Query System**
1. Build HybridQueryEngine
2. Add natural language query parsing
3. Implement combined scoring

### **Phase 5: MCP Integration**
1. Create enhanced MCP tools
2. Add temporal query support
3. Implement analytics tools

### **Phase 6: Performance & Polish**
1. Add caching layer
2. Optimize database indexes
3. Performance testing and tuning

## 🧪 Testing Strategy

### **Unit Tests**
- Enhanced TextSummary model
- IngestionService batch processing
- QueryParser natural language parsing
- HybridQueryEngine scoring algorithms

### **Integration Tests**
- Full ingestion → storage → query pipeline
- Temporal filtering accuracy
- Keyword extraction and matching
- Performance under load

### **End-to-End Tests**
- MCP tool integration
- Real-world query scenarios
- Data persistence across restarts
- Migration and backup/restore

## 📈 Success Metrics

### **Performance Targets**
- **Ingestion**: < 100ms per item, > 1000 items/minute batch
- **Search**: < 200ms for hybrid queries
- **Storage**: < 1GB for 100k summaries
- **Persistence**: < 5s startup time with existing data

### **Query Capabilities**
- Support natural language queries like:
  - "Show me Swift conversations from last week"
  - "Find planning discussions with Alice from June"
  - "What did the support team say about performance yesterday?"

### **Data Management**
- Automatic keyword extraction accuracy > 80%
- Semantic search relevance > 85%
- Temporal filtering precision > 95%
- Zero data loss during migrations

## 🚀 Implementation Timeline

**Week 1-2**: Enhanced data model and persistent storage
**Week 3-4**: Ingestion module and keyword extraction
**Week 5-6**: Hybrid query system and natural language parsing
**Week 7-8**: MCP tool integration and analytics
**Week 9-10**: Performance optimization and testing
**Week 11-12**: Documentation and final polish

This plan transforms the current vector store foundation into a comprehensive, production-ready system for temporal text analysis with semantic search capabilities.