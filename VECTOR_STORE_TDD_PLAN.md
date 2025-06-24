# Vector Store TDD Implementation Plan

## 🎯 Overview
Test-Driven Development plan for implementing vector embedding and text summary storage in the Slunk MCP server. Each step includes specific tests to write before implementation.

## 📋 Implementation Steps

### **Step 1: Foundation - Data Models**

#### **Tests to Write First:**
```swift
// Tests/VectorStoreTests.swift
func testTextSummaryCreation() {
    // Should create TextSummary with required fields
    // Should generate valid UUID
    // Should set timestamps correctly
}

func testTextSummaryValidation() {
    // Should reject empty title
    // Should reject empty content
    // Should reject empty summary
    // Should accept optional fields as nil
}

func testTextSummaryEncoding() {
    // Should encode/decode to/from JSON correctly
    // Should preserve all fields including optional ones
}
```

#### **Implementation:**
- Create `TextSummary.swift` model
- Add proper Codable conformance
- Implement validation logic

---

### **Step 2: Embedding Generation**

#### **Tests to Write First:**
```swift
// Tests/EmbeddingTests.swift
func testNLEmbeddingGeneration() {
    // Should generate 512-dimension vector for text
    // Should return nil for empty text
    // Should be consistent for same input
}

func testEmbeddingService() {
    // Should handle batch processing
    // Should validate input text
    // Should handle NLEmbedding failures gracefully
}
```

#### **Implementation:**
- Create `EmbeddingService.swift`
- Implement NLEmbedding integration
- Add error handling

---

### **Step 3: SQLiteVec Integration & Schema**

#### **Tests to Write First:**
```swift
// Tests/SQLiteVecTests.swift
func testSQLiteVecInitialization() {
    // Should initialize SQLiteVec extension
    // Should create vector table with correct dimensions
    // Should handle SQLiteVec loading failures
}

func testVectorTableCreation() {
    // Should create vec0 virtual table
    // Should set correct embedding dimensions (512)
    // Should create with proper indexes
}

func testSQLiteVecQueries() {
    // Should insert vectors successfully
    // Should perform similarity searches
    // Should return distance scores correctly
}
```

#### **Implementation:**
- Import and configure SQLiteVec
- Create vector table schema with vec0
- Add SQLiteVec initialization to database setup
- Test vector operations with sample data

---

### **Step 4: Vector Store Manager with SQLiteVec**

#### **Tests to Write First:**
```swift
// Tests/VectorStoreManagerTests.swift
func testStoreSummaryWithVector() {
    // Should store summary in GRDB table
    // Should store embedding in SQLiteVec table
    // Should maintain referential integrity
    // Should return unique ID
}

func testSQLiteVecIntegration() {
    // Should connect GRDB with SQLiteVec database
    // Should execute vec0 queries successfully
    // Should handle vector insertion/retrieval
}

func testVectorSimilaritySearch() {
    // Should find similar vectors using SQLiteVec
    // Should return distance scores
    // Should join with relational data correctly
}

func testTransactionAcrossStores() {
    // Should rollback both GRDB and SQLiteVec on failure
    // Should commit both stores together
}
```

#### **Implementation:**
- Create `VectorStoreManager.swift` with SQLiteVec integration
- Setup shared database connection between GRDB and SQLiteVec
- Implement vector operations using vec0 syntax
- Add transaction coordination

---

### **Step 5: SQLiteVec Semantic Search**

#### **Tests to Write First:**
```swift
// Tests/SearchTests.swift
func testSQLiteVecSimilaritySearch() {
    // Should use vec0 MATCH operator for similarity
    // Should return results with distance scores
    // Should join vector results with GRDB data
    // Should respect limit parameter
}

func testVectorSearchWithFilters() {
    // Should combine vector similarity with SQL WHERE clauses
    // Should filter by category and tags after vector search
    // Should maintain performance with hybrid queries
}

func testVectorSearchPerformance() {
    // Should complete searches in <100ms for 1000+ vectors
    // Should use proper indexing for vector operations
}

func testEmptyVectorSearchResults() {
    // Should handle no vector matches gracefully
    // Should return empty array with proper structure
}
```

#### **Implementation:**
- Use SQLiteVec `vec_search()` or `MATCH` operators
- Implement hybrid SQL queries joining vec0 with GRDB tables
- Add distance-to-similarity conversion
- Optimize query performance with proper indexing

---

### **Step 6: MCP Tool - addTextSummary**

#### **Tests to Write First:**
```swift
// Tests/MCPToolsTests.swift
func testAddSummaryTool() {
    // Should accept valid JSON-RPC request
    // Should store summary successfully
    // Should return proper MCP response format
}

func testAddSummaryValidation() {
    // Should reject missing required fields
    // Should return proper error codes
    // Should include helpful error messages
}

func testAddSummaryWithOptionalFields() {
    // Should handle category, tags, sourceURL
    // Should store optional fields correctly
}
```

#### **Implementation:**
- Add `addTextSummary` to MCPServer.swift
- Implement request validation
- Add proper error responses

---

### **Step 7: MCP Tool - searchSummaries**

#### **Tests to Write First:**
```swift
func testSearchSummariesTool() {
    // Should accept search query
    // Should return formatted results
    // Should include similarity scores
}

func testSearchWithParameters() {
    // Should respect limit parameter
    // Should filter by category
    // Should filter by minimum similarity
}

func testSearchEmptyQuery() {
    // Should handle empty query
    // Should return appropriate response
}
```

#### **Implementation:**
- Add `searchSummaries` to MCPServer.swift
- Format search results for MCP response
- Handle edge cases

---

### **Step 8: MCP Tool - listSummaries**

#### **Tests to Write First:**
```swift
func testListSummariesTool() {
    // Should return all summaries by default
    // Should respect limit parameter
    // Should sort by specified field
}

func testListWithFilters() {
    // Should filter by category
    // Should filter by tag
    // Should combine multiple filters
}
```

#### **Implementation:**
- Add `listSummaries` to MCPServer.swift
- Implement sorting and filtering
- Add pagination support

---

### **Step 9: MCP Tool - deleteSummary**

#### **Tests to Write First:**
```swift
func testDeleteSummaryTool() {
    // Should delete existing summary
    // Should remove from both tables
    // Should return success confirmation
}

func testDeleteNonexistentSummary() {
    // Should handle missing ID gracefully
    // Should return appropriate error
}
```

#### **Implementation:**
- Add `deleteSummary` to MCPServer.swift
- Implement cascading delete
- Add confirmation response

---

### **Step 10: Integration Testing**

#### **Tests to Write First:**
```swift
// Tests/IntegrationTests.swift
func testFullWorkflow() {
    // Should add summary via MCP
    // Should search and find it
    // Should list it in results
    // Should delete it successfully
}

func testMCPProtocolCompliance() {
    // Should handle all JSON-RPC edge cases
    // Should return proper error codes
    // Should maintain protocol format
}

func testPerformanceWithLargeDataset() {
    // Should handle 1000+ summaries
    // Should maintain sub-100ms search times
    // Should not leak memory
}
```

#### **Implementation:**
- Create comprehensive integration tests
- Test with realistic data volumes
- Verify MCP protocol compliance

---

### **Step 11: UI Integration**

#### **Tests to Write First:**
```swift
// Tests/UITests.swift
func testServerStatusDisplay() {
    // Should show vector store status
    // Should display summary count
    // Should update in real-time
}

func testMCPConfigGeneration() {
    // Should include new tools in config
    // Should copy complete configuration
}
```

#### **Implementation:**
- Update ServerManager.swift
- Add vector store status to UI
- Update MCP config generation

---

### **Step 12: Error Handling & Edge Cases**

#### **Tests to Write First:**
```swift
// Tests/EdgeCaseTests.swift
func testDatabaseCorruption() {
    // Should handle corrupted vector table
    // Should recover gracefully
    // Should not crash server
}

func testEmbeddingServiceFailure() {
    // Should handle NLEmbedding unavailable
    // Should provide fallback behavior
    // Should log appropriate errors
}

func testMemoryPressure() {
    // Should handle large embeddings
    // Should not exceed memory limits
    // Should clean up resources
}
```

#### **Implementation:**
- Add comprehensive error handling
- Implement fallback strategies
- Add resource cleanup

---

## 🗂️ **File Structure**

```
slunk-swift/slunk-swift/
├── Models/
│   ├── TextSummary.swift          # Step 1
│   └── SearchResult.swift         # Step 5
├── Services/
│   ├── EmbeddingService.swift     # Step 2
│   └── VectorStoreManager.swift   # Step 4
├── Database/
│   └── SQLiteVecSchema.swift      # Step 3 (SQLiteVec setup)
├── MCPServer.swift                # Steps 6-9 (updated)
└── ServerManager.swift            # Step 11 (updated)

slunk-swiftTests/
├── Models/
│   └── TextSummaryTests.swift
├── Services/
│   ├── EmbeddingServiceTests.swift
│   └── VectorStoreManagerTests.swift
├── Database/
│   └── SQLiteVecTests.swift       # SQLiteVec specific tests
├── Integration/
│   └── MCPVectorStoreTests.swift
└── EdgeCases/
    └── ErrorHandlingTests.swift
```

## 🎯 **TDD Workflow for Each Step**

### **Red-Green-Refactor Cycle:**

1. **🔴 Red**: Write failing tests first
   ```swift
   func testFeature() {
       // Arrange
       let input = "test data"
       
       // Act & Assert
       XCTAssertEqual(expectedOutput, actualOutput)
   }
   ```

2. **🟢 Green**: Write minimal code to pass tests
   ```swift
   func implementFeature() -> String {
       return "minimal implementation"
   }
   ```

3. **🔄 Refactor**: Improve code while keeping tests green
   ```swift
   func implementFeature() -> String {
       // Clean, optimized implementation
       return processedResult
   }
   ```

4. **✅ Commit**: After each successful step, commit before proceeding
   ```bash
   git add .
   git commit -m "Implement [Step X]: [Feature Name] with passing tests
   
   🤖 Generated with Claude Code
   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

## ✅ **Definition of Done for Each Step**

- [ ] All tests written and passing
- [ ] Code coverage > 80%
- [ ] No compiler warnings
- [ ] Documentation comments added
- [ ] MCP protocol compliance verified
- [ ] Performance requirements met
- [ ] Error handling tested
- [ ] **Changes committed to git** before proceeding to next step

## 🚀 **Getting Started**

1. **Choose a step** (recommend starting with Step 1)
2. **Write the tests first** using the provided templates
3. **Run tests** (they should fail - Red)
4. **Implement minimal code** to make tests pass (Green)
5. **Refactor** for clean, maintainable code
6. **Verify** all acceptance criteria met
7. **✅ COMMIT** changes with descriptive message
8. **Move to next step** only after successful commit

### **⚠️ Important: Commit Before Each Step**

**Never proceed to the next step without committing.** This ensures:
- ✅ **Progress tracking** - Each step is saved in git history
- ✅ **Safe rollback** - Easy to revert if issues arise
- ✅ **Clear milestones** - Visible progress in commit log
- ✅ **Collaboration ready** - Work can be shared at any point

### **Commit Message Template:**
```bash
git commit -m "Step [X]: [Brief description]

- ✅ Tests written and passing
- ✅ [Specific feature] implemented
- ✅ Error handling added
- ✅ Documentation updated

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
```

This TDD approach ensures robust, well-tested code with clear progress tracking through git commits.