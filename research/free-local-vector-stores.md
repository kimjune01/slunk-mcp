# Free Local-Only Vector Stores for Semantic Similarity Search

## Overview

This document focuses exclusively on free, local-only vector database solutions that can be deployed without cloud dependencies or ongoing costs.

## 1. Open-Source Self-Hosted Solutions

### Qdrant (Self-Hosted)
- **Cost**: Free (open-source)
- **Deployment**: Docker, binary, or from source
- **Features**: Real-time updates, extensive filtering, low overhead
- **Swift Integration**: REST API via URLSession
- **Setup**:
  ```bash
  docker run -p 6333:6333 qdrant/qdrant
  ```
- **Pros**: Low resource usage, excellent filtering capabilities
- **Cons**: Requires server setup and maintenance

### Milvus (Self-Hosted)
- **Cost**: Free (open-source)
- **Deployment**: Docker Compose, Kubernetes, or standalone
- **Features**: High performance, 11 index types, billions of vectors support
- **Swift Integration**: REST API via URLSession
- **Setup**:
  ```bash
  docker run -p 19530:19530 milvusdb/milvus:latest
  ```
- **Pros**: Best performance among open-source options
- **Cons**: More complex setup, higher resource requirements

### Weaviate (Self-Hosted)
- **Cost**: Free (open-source)
- **Deployment**: Docker, Kubernetes
- **Features**: Hybrid search (vector + keyword), GraphQL API
- **Swift Integration**: REST API and GraphQL via URLSession
- **Setup**:
  ```bash
  docker run -p 8080:8080 semitechnologies/weaviate:latest
  ```
- **Pros**: Hybrid search capabilities, modular design
- **Cons**: Higher resource usage than Qdrant

## 2. Embedded Vector Libraries

### FAISS (Facebook AI Similarity Search)
- **Cost**: Free (open-source)
- **Deployment**: Embedded library in your application
- **Features**: GPU acceleration, advanced indexing, memory-efficient
- **Swift Integration**: Limited - requires C++ bridging or Python subprocess
- **Performance**: 8.5x faster than previous state-of-the-art
- **Pros**: Highest performance, no server required
- **Cons**: Complex Swift integration, requires technical expertise

### Annoy (Spotify)
- **Cost**: Free (open-source)
- **Deployment**: Embedded library
- **Features**: Memory-efficient, immutable indexes, optimized for read-heavy workloads
- **Swift Integration**: No native Swift support, requires bridging
- **Pros**: Simple, fast for static datasets
- **Cons**: No native Swift support, limited flexibility

### ScaNN (Google)
- **Cost**: Free (open-source)
- **Deployment**: Embedded library
- **Features**: Anisotropic vector quantization, optimized for accuracy
- **Swift Integration**: No native Swift support
- **Performance**: 2x better accuracy than competitors
- **Pros**: Excellent accuracy for NLP tasks
- **Cons**: No Swift support, requires more tuning

## 3. Database Extensions (Free)

### PostgreSQL + pgvector
- **Cost**: Free (open-source extension)
- **Deployment**: Local PostgreSQL installation
- **Features**: SQL integration, up to 2,000 dimensions
- **Swift Integration**: PostgreSQL Swift drivers available
- **Setup**:
  ```bash
  brew install postgresql
  git clone https://github.com/pgvector/pgvector.git
  cd pgvector && make && make install
  ```
- **Pros**: SQL integration, mature ecosystem
- **Cons**: Slower than specialized vector databases

### SQLite + sqlite-vss
- **Cost**: Free (open-source extension)
- **Deployment**: SQLite with VSS extension
- **Features**: Lightweight, embedded, FAISS-based indexing
- **Swift Integration**: SQLite Swift libraries support extensions
- **Setup**: Compile SQLite with VSS extension
- **Pros**: Lightweight, embeddable, familiar SQL interface
- **Cons**: Limited scalability compared to dedicated solutions

## 4. Swift-Native Local Solutions

### ObjectBox Swift (Community Edition)
- **Cost**: Free for development, open-source community version
- **Deployment**: Embedded in iOS/macOS app
- **Features**: Native Swift, HNSW algorithm, offline operation
- **Swift Integration**: Native Swift APIs
- **Performance**: Millisecond search in millions of entries
- **Setup**:
  ```swift
  dependencies: [
      .package(url: "https://github.com/objectbox/objectbox-swift.git", from: "1.0.0")
  ]
  ```
- **Pros**: Native Swift, privacy-focused, no server required
- **Cons**: Community edition limitations

### USearch with Swift Bindings
- **Cost**: Free (open-source)
- **Deployment**: Embedded in iOS/macOS app
- **Features**: Scales to 100M+ entries on iPhone, real-time search
- **Swift Integration**: Swift package available
- **Setup**:
  ```swift
  dependencies: [
      .package(url: "https://github.com/unum-cloud/usearch.git", from: "2.0.0")
  ]
  ```
- **Pros**: Excellent mobile performance, real-time capabilities
- **Cons**: Less mature than ObjectBox

### SVDB (Swift Vector Database)
- **Cost**: Free (open-source)
- **Deployment**: Native Swift library
- **Features**: Pure Swift implementation
- **Swift Integration**: Native Swift
- **Status**: Early stage, less feature-complete
- **Pros**: Pure Swift, simple integration
- **Cons**: Limited features, early development stage

## 5. Custom Swift Implementation with Core Data + SQLite

### DIY Vector Search with SQLite
- **Cost**: Free
- **Deployment**: Custom implementation using SQLite
- **Features**: Basic vector similarity using SQLite functions
- **Swift Integration**: Native through SQLite Swift libraries
- **Implementation**:
  ```swift
  // Store vectors as JSON or binary blobs
  // Implement basic cosine similarity in SQL
  SELECT id, vector_data, 
         (vector_dot_product / (vector_magnitude1 * vector_magnitude2)) as similarity
  FROM vectors 
  ORDER BY similarity DESC 
  LIMIT 10
  ```
- **Pros**: Full control, minimal dependencies
- **Cons**: Limited performance, manual implementation required

## Recommendations by Use Case

### iOS/macOS App Development
1. **ObjectBox Swift Community Edition**: Best native experience
2. **USearch**: Good performance for real-time search
3. **SQLite + custom implementation**: For simple similarity search

### Python Backend + Swift Frontend
1. **Self-hosted Qdrant**: Low resource usage, excellent API
2. **FAISS with Python wrapper**: Highest performance
3. **PostgreSQL + pgvector**: If already using PostgreSQL

### Minimal Resource Usage
1. **SQLite + sqlite-vss**: Lightweight embedded solution
2. **Qdrant**: Lowest overhead among full-featured databases
3. **Custom SQLite implementation**: Most minimal approach

### High Performance Requirements
1. **Self-hosted Milvus**: Best performance among open-source
2. **FAISS**: Highest performance but complex integration
3. **USearch**: Best performance for mobile devices

## Implementation Example: USearch with Swift

```swift
import USearch

// Create index
let index = USearchIndex(
    metric: .cosine,
    dimensions: 384,
    connectivity: 16,
    expansionAdd: 128,
    expansionSearch: 64
)

// Add vectors
let vectors: [[Float]] = loadVectors()
for (id, vector) in vectors.enumerated() {
    try index.add(label: UInt64(id), vector: vector)
}

// Search
let queryVector: [Float] = getQueryVector()
let results = try index.search(vector: queryVector, count: 10)

for result in results {
    print("ID: \(result.label), Distance: \(result.distance)")
}
```

## Implementation Example: Self-Hosted Qdrant with Swift

```swift
struct QdrantClient {
    private let baseURL = "http://localhost:6333"
    private let session = URLSession.shared
    
    func search(vector: [Float], collection: String, limit: Int = 10) async throws -> [SearchResult] {
        let url = URL(string: "\(baseURL)/collections/\(collection)/points/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let searchRequest = QdrantSearchRequest(
            vector: vector,
            limit: limit,
            with_payload: true
        )
        
        request.httpBody = try JSONEncoder().encode(searchRequest)
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(QdrantSearchResponse.self, from: data)
        
        return response.result
    }
}
```

## Resource Requirements Comparison

### Minimal Resources (< 100MB RAM)
- SQLite + custom implementation
- ObjectBox Swift (community)
- USearch

### Low Resources (100MB - 1GB RAM)
- Qdrant (single node)
- SQLite + sqlite-vss
- PostgreSQL + pgvector (small datasets)

### Medium Resources (1GB+ RAM)
- Milvus (standalone)
- Weaviate (single node)
- FAISS (large datasets)

## Setup Complexity Ranking

1. **Easiest**: ObjectBox Swift, USearch (native Swift packages)
2. **Easy**: SQLite + custom implementation
3. **Moderate**: Qdrant Docker, PostgreSQL + pgvector
4. **Complex**: Milvus setup, FAISS integration
5. **Most Complex**: Custom FAISS with Swift bridging

## 6. Local Embedding Generation Options

### Apple's Built-in Solutions

#### NLEmbedding (Recommended for Swift)
- **Cost**: Free (built into macOS/iOS)
- **Features**: 512-dimensional embeddings, 27 languages supported
- **Swift Integration**: Native framework
- **Setup**:
  ```swift
  let embedding = NLEmbedding.sentenceEmbedding(for: .english)
  let vector = embedding?.vector(for: "Your text here")
  ```
- **Pros**: Zero setup, optimized for Apple Silicon, privacy-focused
- **Cons**: Limited customization, Apple ecosystem only

#### Core ML Models
- **Cost**: Free (after conversion)
- **Features**: Custom models, GPU/Neural Engine acceleration
- **Models**: Convert Hugging Face models to Core ML
- **Setup**:
  ```python
  # Convert with coremltools
  import coremltools as ct
  from transformers import AutoModel
  
  model = AutoModel.from_pretrained("sentence-transformers/all-MiniLM-L6-v2")
  coreml_model = ct.convert(model, inputs=[...])
  coreml_model.save("embedding_model.mlpackage")
  ```
- **Pros**: Excellent performance, battery efficient
- **Cons**: Requires model conversion process

### Swift-Native Embedding Libraries

#### SimilaritySearchKit
- **Cost**: Free (open-source)
- **Features**: On-device embeddings, semantic search, multiple NLP models
- **Swift Integration**: Native Swift package
- **Setup**:
  ```swift
  dependencies: [
      .package(url: "https://github.com/ZachNagengast/similarity-search-kit.git", from: "1.0.0")
  ]
  ```
- **Pros**: Easy integration, privacy-focused, production-ready
- **Cons**: Limited model selection

#### Model2Vec.swift
- **Cost**: Free (open-source)
- **Features**: Ultra-compact embeddings (32.7MB), Rust backend
- **Performance**: Fast inference, 32K tokens × 256 dimensions
- **Swift Integration**: Native Swift bindings
- **Pros**: Very small memory footprint, fast
- **Cons**: Lower embedding quality, limited vocabulary

### Open-Source Embedding Models

#### Sentence Transformers (via Python bridge)
- **Cost**: Free (open-source)
- **Popular Models**:
  - `all-MiniLM-L6-v2`: 22M params, 384-dim (fastest)
  - `bge-small-en`: 33M params, 384-dim (best quality/size ratio)
  - `e5-small-v2`: 33M params, 384-dim (multilingual)
- **Setup**:
  ```bash
  pip install sentence-transformers
  ```
- **Swift Integration**: Via Python subprocess or conversion to Core ML
- **Pros**: Excellent quality, many model options
- **Cons**: Requires Python runtime or conversion

#### MLX Framework (Apple Silicon Optimized)
- **Cost**: Free (open-source)
- **Features**: Native Apple Silicon acceleration, Hugging Face compatible
- **Performance**: Unified memory, no CPU/GPU copying overhead
- **Setup**:
  ```bash
  pip install mlx-lm
  ```
- **Swift Integration**: Via Python bridge or native bindings
- **Pros**: Optimized for Apple Silicon, excellent performance
- **Cons**: Apple Silicon only, requires Python

### ONNX Runtime Integration
- **Cost**: Free (open-source)
- **Features**: 130,000+ Hugging Face models supported
- **Performance**: Hardware acceleration, optimization levels
- **Limitations**: Metal/MPS issues on Apple Silicon via Docker
- **Setup**:
  ```bash
  pip install onnxruntime
  ```
- **Swift Integration**: Via ONNX Swift bindings
- **Pros**: Huge model selection, cross-platform
- **Cons**: Apple Silicon compatibility issues

## Performance Comparison (Apple Silicon)

### Speed Ranking
1. **NLEmbedding**: Fastest (native framework)
2. **Core ML**: Very fast (Neural Engine optimized)
3. **MLX**: Fast (Apple Silicon optimized)
4. **SimilaritySearchKit**: Good (optimized Swift)
5. **ONNX Runtime**: Variable (depends on optimization)

### Memory Usage
1. **Model2Vec.swift**: ~35MB
2. **NLEmbedding**: ~50MB
3. **all-MiniLM-L6-v2**: ~100MB
4. **bge-small-en**: ~150MB
5. **e5-small-v2**: ~150MB

### Quality Ranking
1. **bge-small-en**: Highest quality
2. **e5-small-v2**: Excellent multilingual
3. **all-MiniLM-L6-v2**: Good balance
4. **NLEmbedding**: Good for general use
5. **Model2Vec.swift**: Lower quality, very fast

## Complete Implementation Example

### Swift App with Local Embeddings + Vector Search
```swift
import NaturalLanguage
import Foundation

class LocalSemanticSearch {
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)
    private let vectorStore: VectorStore
    
    init() {
        self.vectorStore = ObjectBoxVectorStore() // or USearch
    }
    
    func addDocument(_ text: String, id: String) async throws {
        guard let vector = embedding?.vector(for: text) else {
            throw EmbeddingError.failedToGenerate
        }
        
        try await vectorStore.store(vector: vector, id: id, metadata: ["text": text])
    }
    
    func search(_ query: String, limit: Int = 10) async throws -> [SearchResult] {
        guard let queryVector = embedding?.vector(for: query) else {
            throw EmbeddingError.failedToGenerate
        }
        
        return try await vectorStore.search(vector: queryVector, limit: limit)
    }
}
```

### Python Backend with MLX
```python
import mlx.core as mx
from mlx_lm import load
from sentence_transformers import SentenceTransformer

class LocalEmbeddingService:
    def __init__(self):
        # Load optimized for Apple Silicon
        self.model = SentenceTransformer('all-MiniLM-L6-v2')
        
    def embed_text(self, text: str) -> list[float]:
        embedding = self.model.encode([text])
        return embedding[0].tolist()
    
    def embed_batch(self, texts: list[str]) -> list[list[float]]:
        embeddings = self.model.encode(texts)
        return embeddings.tolist()
```

## Recommendations by Use Case

### iOS/macOS App (Recommended)
1. **NLEmbedding** + **ObjectBox Swift**: Best native experience
2. **SimilaritySearchKit** + **USearch**: Production-ready alternative
3. **Core ML model** + **ObjectBox**: Custom model needs

### Python Backend + Swift Frontend
1. **MLX** + **Self-hosted Qdrant**: Best performance
2. **Sentence Transformers** + **Milvus**: Mature ecosystem
3. **ONNX Runtime** + **PostgreSQL + pgvector**: Flexible setup

### Minimal Resource Usage
1. **Model2Vec.swift** + **SQLite**: Ultra-lightweight
2. **NLEmbedding** + **Custom SQLite**: Apple-optimized minimal
3. **all-MiniLM-L6-v2** + **USearch**: Balanced minimal

## Conclusion

For free local-only vector search with embeddings:

**Complete iOS/macOS Solution:**
- **Embeddings**: NLEmbedding (native) or SimilaritySearchKit
- **Vector Store**: ObjectBox Swift (community) or USearch
- **Benefits**: Zero cloud dependencies, privacy-focused, battery efficient

**Backend Services:**
- **Embeddings**: MLX or Sentence Transformers
- **Vector Store**: Self-hosted Qdrant or Milvus
- **Benefits**: High performance, scalable, customizable

**Minimal Implementation:**
- **Embeddings**: NLEmbedding or Model2Vec.swift
- **Vector Store**: SQLite with custom similarity functions
- **Benefits**: Smallest footprint, simple deployment

All options are completely free, run locally without cloud dependencies, and provide production-ready semantic search capabilities.