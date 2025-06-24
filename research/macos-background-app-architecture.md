# macOS Background App Architecture Research

## Overview

Research on building a background macOS app using Swift with Model Context Protocol (MCP), SQLite, and ChromaDB integration for persistent local storage and vector search capabilities.

## Architecture Overview

A background macOS app with these technologies would follow this architecture:

```
┌─────────────────────────────────────────┐
│           macOS Background App          │
├─────────────────────────────────────────┤
│ • Menu Bar Interface (SwiftUI)         │
│ • Background Activity Scheduler        │
│ • MCP Client Integration               │
│ • Local Semantic Search Manager        │
│ • NLEmbedding Service                  │
└─────────────────────────────────────────┘
           │              │              │
    ┌──────▼──────┐  ┌────▼────────┐  ┌──▼─────────┐
    │  SQLite     │  │ SQLiteVec   │  │ NLEmbedding│
    │ (GRDB.swift)│  │ (Vectors)   │  │ (Apple)    │
    │ Relational  │  │ Similarity  │  │ 512-dim    │
    │ Data        │  │ Search      │  │ Embeddings │
    └─────────────┘  └─────────────┘  └────────────┘
```

## Key Swift Dependencies

### 1. MCP Integration
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0")
]
```

**Features:**
- Official Swift SDK for MCP protocol
- Client and server components
- Supports stdio and HTTP+SSE transports
- Swift 6+ with async/await support
- Maintained by MCP organization

### 2. SQLite Integration (Relational Data)
```swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.5.0")
]
```

**GRDB.swift is recommended because:**
- Most actively maintained SQLite library for Swift
- Full async/await support
- Built-in migrations and database observation
- Excellent concurrency with WAL mode
- macOS 10.15+ compatibility

### 3. Vector Storage with SQLiteVec
```swift
dependencies: [
    .package(url: "https://github.com/jkrukowski/SQLiteVec.git", from: "0.0.9")
]
```

**SQLiteVec features:**
- Swift bindings for sqlite-vec extension
- Perfect for NLEmbedding 512-dimensional vectors
- SQL interface for vector similarity search
- Actor-based design with async/await
- Local-only, no cloud dependencies

### 4. Embeddings with Apple's NLEmbedding
```swift
import NaturalLanguage

// Built into macOS/iOS - no external dependency
let embedding = NLEmbedding.sentenceEmbedding(for: .english)
```

**NLEmbedding benefits:**
- Native Apple framework (zero setup)
- Optimized for Apple Silicon
- 512-dimensional embeddings
- 27 languages supported
- Privacy-focused (never leaves device)

## Implementation Strategy

### 1. Background App Structure
```swift
@main
struct VectorSearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Vector Search", systemImage: "magnifyingglass") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize background services
        Task {
            await setupServices()
        }
    }
}
```

### 2. Service Management
```swift
actor DataService {
    private let dbQueue: DatabaseQueue           // GRDB for relational data
    private let vectorDB: SQLiteVec.Database     // SQLiteVec for embeddings
    private let mcpClient: Client                // MCP integration
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)
    
    init() async throws {
        // Initialize GRDB for relational data
        self.dbQueue = try DatabaseQueue(path: "app_data.db")
        
        // Initialize SQLiteVec for vector storage
        try SQLiteVec.initialize()
        self.vectorDB = try SQLiteVec.Database(.file("vectors.db"))
        
        // Initialize MCP client
        self.mcpClient = Client(name: "VectorApp", version: "1.0.0")
        
        await setupDatabases()
        await connectMCP()
    }
    
    private func setupDatabases() async throws {
        // Setup relational tables
        try await dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS documents (
                    id INTEGER PRIMARY KEY,
                    title TEXT NOT NULL,
                    content TEXT NOT NULL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            """)
        }
        
        // Setup vector table
        try await vectorDB.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS document_embeddings USING vec0(
                embedding float[512],
                document_id INTEGER
            )
        """)
    }
}
```

### 3. Local Semantic Search Integration
Combining NLEmbedding + SQLiteVec for powerful local search:

```swift
struct SemanticSearchManager {
    private let dataService: DataService
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)
    
    func addDocument(title: String, content: String) async throws -> Int {
        // Store relational data
        let documentId = try await dataService.dbQueue.write { db -> Int in
            try db.execute(sql: """
                INSERT INTO documents (title, content) VALUES (?, ?)
            """, arguments: [title, content])
            return db.lastInsertedRowID
        }
        
        // Generate and store embedding
        guard let vector = embedding?.vector(for: content) else {
            throw EmbeddingError.failedToGenerate
        }
        
        try await dataService.vectorDB.execute("""
            INSERT INTO document_embeddings(embedding, document_id) 
            VALUES (?, ?)
        """, params: [vector, documentId])
        
        return documentId
    }
    
    func searchSimilar(query: String, limit: Int = 10) async throws -> [SearchResult] {
        guard let queryVector = embedding?.vector(for: query) else {
            throw EmbeddingError.failedToGenerate
        }
        
        // Find similar vectors
        let vectorResults = try await dataService.vectorDB.query("""
            SELECT document_id, distance 
            FROM document_embeddings 
            WHERE embedding MATCH ? 
            ORDER BY distance 
            LIMIT ?
        """, params: [queryVector, limit])
        
        // Get document details from relational DB
        let documentIds = vectorResults.compactMap { $0["document_id"] as? Int }
        let placeholders = Array(repeating: "?", count: documentIds.count).joined(separator: ",")
        
        let documents = try await dataService.dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT id, title, content, created_at 
                FROM documents 
                WHERE id IN (\(placeholders))
            """, arguments: StatementArguments(documentIds))
        }
        
        // Combine results
        return vectorResults.compactMap { vectorRow in
            guard let docId = vectorRow["document_id"] as? Int,
                  let distance = vectorRow["distance"] as? Double,
                  let doc = documents.first(where: { $0["id"] == docId }) else {
                return nil
            }
            
            return SearchResult(
                id: docId,
                title: doc["title"],
                content: doc["content"],
                similarity: 1.0 - distance,
                createdAt: doc["created_at"]
            )
        }
    }
}
```

### 4. Background Task Scheduling
```swift
class BackgroundTaskManager {
    private let scheduler = NSBackgroundActivityScheduler(
        identifier: "com.app.vector-sync"
    )
    
    func setupPeriodicTasks() {
        scheduler.repeats = true
        scheduler.interval = 300 // 5 minutes
        scheduler.qualityOfService = .background
        
        scheduler.schedule { completion in
            Task {
                await self.performVectorSync()
                completion(.finished)
            }
        }
    }
}
```

## Swift MCP Client Libraries

### Official Swift SDK
- **Repository**: https://github.com/modelcontextprotocol/swift-sdk
- **Installation**: Swift Package Manager
- **Features**: 
  - Implements both client and server components
  - Supports MCP specification version 2025-03-26 (latest)
  - Built-in stdio transport support
  - Logging configuration support
  - Platform support: Swift 6+ (macOS, Linux, Windows)

### Alternative Implementations
- **swift-mcp-client**: Multiple server management, JSON config loading
- **SwiftMCP by Cocoanetics**: JSON-RPC over various transports, macro-based tools
- **swift-context-protocol**: Swift distributed actor model approach

## SQLite Swift Libraries Comparison

### GRDB.swift (Recommended)
- **Latest Version**: 7.5.0+ (actively maintained)
- **Requirements**: iOS 13.0+, macOS 10.15+, Swift 6+
- **Features**: 
  - Comprehensive toolkit with query interface
  - Built-in migrations, full-text search, database observation
  - Multi-threaded support with WAL mode
  - Full async/await support
- **Performance**: Competitive with raw SQLite C API

### SQLite.swift
- **Features**: Type-safe, pure Swift implementation
- **Performance**: Slightly slower than FMDB but clean Swift integration
- **Pros**: Clean Swift interfaces, type safety
- **Cons**: Less frequent updates

### FMDB
- **Features**: Mature Objective-C wrapper
- **Performance**: Best performance after raw SQLite C API
- **Pros**: Battle-tested, excellent for cross-platform
- **Cons**: Objective-C based, verbose syntax

## ChromaDB Integration Strategies

### Current Limitations
- No official Swift client library
- Available clients: Python, JavaScript, experimental Go
- macOS installation requires Python dependencies

### Recommended Approach
1. Deploy ChromaDB as Docker service
2. Create REST API wrapper
3. Use native Swift URLSession for communication
4. Implement proper authentication and retry logic

### Vector Database Alternatives
- **Qdrant**: High-performance Rust-based with REST API
- **Milvus**: Open-source Go-based with RESTful endpoints
- **Pinecone**: Managed cloud service with REST API
- **Weaviate**: GraphQL interface
- **MongoDB Atlas Vector Search**: Full REST API support

## Background App Implementation

### Menu Bar App Architecture
```swift
// Menu bar app structure
@main
struct MenuBarApp: App {
    var body: some Scene {
        MenuBarExtra("App Name", systemImage: "icon") {
            ContentView()
        }
    }
}
```

### Launch Agent Configuration
```xml
<!-- ~/Library/LaunchAgents/com.app.service.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.app.service</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/app</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

### Background Task Management
- **NSBackgroundActivityScheduler**: For periodic operations
- **App Nap Management**: Prevent suspension when needed
- **Power Management**: Respect system energy policies
- **XPC Services**: For process isolation

## Deployment Considerations

### 1. Local Database Setup
```swift
// No external servers needed - everything is local!

// App bundle structure:
MyApp.app/
├── Contents/
│   ├── MacOS/MyApp
│   ├── Resources/
│   └── Frameworks/
└── Databases/ (created at runtime)
    ├── app_data.db      (GRDB - relational data)
    └── vectors.db       (SQLiteVec - embeddings)
```

### 2. App Sandboxing
For App Store distribution:
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>LSUIElement</key>
<true/>
```

### 3. Entitlements
- `com.apple.security.network.client`: Outgoing connections
- `com.apple.security.files.user-selected.read-write`: File access
- `LSUIElement`: Hide from Dock

## Performance Optimizations

### Database Optimizations
- **WAL mode**: Enable for both GRDB and SQLiteVec for concurrent access
- **Separate databases**: Relational and vector data in different files
- **Batch operations**: Insert multiple embeddings in transactions
- **Proper indexing**: Index frequently queried relational columns

### Vector Search Optimizations
- **Dimension optimization**: NLEmbedding's 512 dimensions are well-suited for SQLiteVec
- **Batch embedding generation**: Process multiple texts together
- **Result caching**: Cache frequent queries in memory
- **Async processing**: Generate embeddings on background queues

### Local-First Benefits
- **No network latency**: All operations are local
- **Offline capability**: Works without internet connection
- **Privacy**: Data never leaves the device
- **Cost**: No API usage costs

### Memory Management
- Use actors for thread-safe operations
- Implement proper resource disposal
- Monitor memory usage patterns
- Leverage Swift's automatic memory management

### Power Management
- Use NSBackgroundActivityScheduler appropriately
- Respect App Nap when possible
- Monitor thermal state
- Implement graceful degradation

## Security Considerations

### App Sandboxing
- Minimal entitlements approach
- Test both sandboxed and non-sandboxed versions
- Monitor Console.app for violations

### Network Security
- Use HTTPS for all external communications
- Implement proper authentication
- Validate all API responses
- Handle sensitive data appropriately

### Data Protection
- Encrypt sensitive local data
- Secure credential storage
- Implement proper access controls
- Regular security audits

## Conclusion

This updated architecture provides a **completely local solution** for semantic search in macOS background apps:

### Technology Stack
1. **MCP Integration**: Official Swift SDK for protocol communication
2. **Relational Data**: GRDB.swift for robust SQLite management
3. **Vector Storage**: SQLiteVec for embedding similarity search
4. **Embeddings**: Apple's NLEmbedding for privacy-focused text vectorization
5. **Background Services**: Proper task scheduling and power management

### Key Advantages
- **🔒 Privacy-First**: All data stays on device, no cloud dependencies
- **⚡ Performance**: Native Apple Silicon optimization with NLEmbedding
- **💾 Efficiency**: Separate databases for relational and vector data
- **🔄 Offline**: Complete functionality without internet connection
- **💰 Cost-Effective**: No API usage fees or cloud storage costs
- **🛡️ Secure**: Sandboxed architecture suitable for App Store distribution

### Perfect For
- Personal knowledge management apps
- Document search and organization
- Note-taking with AI-powered features
- Local RAG (Retrieval Augmented Generation) systems
- Privacy-focused AI assistants
- Offline semantic search applications

This architecture enables Apple Intelligence-style features while maintaining complete user privacy and data control.