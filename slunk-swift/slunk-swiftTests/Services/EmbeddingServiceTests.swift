import XCTest
import NaturalLanguage
@testable import slunk_swift

final class EmbeddingServiceTests: XCTestCase {
    
    var embeddingService: EmbeddingService!
    
    override func setUp() {
        super.setUp()
        embeddingService = EmbeddingService()
    }
    
    override func tearDown() {
        embeddingService = nil
        super.tearDown()
    }
    
    func testNLEmbeddingGeneration() {
        // Should generate 512-dimension vector for text
        let text = "This is a test sentence for embedding generation."
        let embedding = embeddingService.generateEmbedding(for: text)
        
        XCTAssertNotNil(embedding, "Should generate embedding for valid text")
        XCTAssertEqual(embedding?.count, 512, "Should generate 512-dimension vector")
        
        // Vector values should be within reasonable range for normalized embeddings
        if let embedding = embedding {
            for value in embedding {
                XCTAssertTrue(value >= -1.0 && value <= 1.0, "Embedding values should be normalized between -1 and 1")
            }
        }
    }
    
    func testNLEmbeddingWithEmptyText() {
        // Should return nil for empty text
        let emptyText = ""
        let embedding = embeddingService.generateEmbedding(for: emptyText)
        
        XCTAssertNil(embedding, "Should return nil for empty text")
        
        // Should also return nil for whitespace-only text
        let whitespaceText = "   \n\t  "
        let whitespaceEmbedding = embeddingService.generateEmbedding(for: whitespaceText)
        
        XCTAssertNil(whitespaceEmbedding, "Should return nil for whitespace-only text")
    }
    
    func testNLEmbeddingConsistency() {
        // Should be consistent for same input
        let text = "Consistent embedding test text"
        let embedding1 = embeddingService.generateEmbedding(for: text)
        let embedding2 = embeddingService.generateEmbedding(for: text)
        
        XCTAssertNotNil(embedding1)
        XCTAssertNotNil(embedding2)
        XCTAssertEqual(embedding1?.count, embedding2?.count)
        
        // Embeddings should be identical for the same input
        if let emb1 = embedding1, let emb2 = embedding2 {
            for (index, value) in emb1.enumerated() {
                XCTAssertEqual(value, emb2[index], accuracy: 0.0001, "Embeddings should be consistent for same input")
            }
        }
    }
    
    func testEmbeddingServiceBatchProcessing() {
        // Should handle batch processing
        let texts = [
            "First test sentence",
            "Second test sentence", 
            "Third test sentence"
        ]
        
        let embeddings = embeddingService.generateEmbeddings(for: texts)
        
        XCTAssertEqual(embeddings.count, texts.count, "Should return embedding for each input text")
        
        for embedding in embeddings {
            XCTAssertNotNil(embedding, "Each embedding should be generated successfully")
            XCTAssertEqual(embedding?.count, 512, "Each embedding should have 512 dimensions")
        }
    }
    
    func testEmbeddingServiceValidation() {
        // Should validate input text
        let validTexts = ["Valid text", "Another valid text"]
        let invalidTexts = ["", "   ", "\n\t"]
        
        let validEmbeddings = embeddingService.generateEmbeddings(for: validTexts)
        let invalidEmbeddings = embeddingService.generateEmbeddings(for: invalidTexts)
        
        // Valid texts should generate embeddings
        for embedding in validEmbeddings {
            XCTAssertNotNil(embedding, "Valid text should generate embedding")
        }
        
        // Invalid texts should return nil
        for embedding in invalidEmbeddings {
            XCTAssertNil(embedding, "Invalid text should return nil embedding")
        }
    }
    
    func testEmbeddingServiceErrorHandling() {
        // Should handle NLEmbedding failures gracefully
        // Test with extremely long text that might cause issues
        let veryLongText = String(repeating: "This is a very long text that might cause embedding generation issues. ", count: 1000)
        
        // Should not crash and should either return a valid embedding or nil
        let embedding = embeddingService.generateEmbedding(for: veryLongText)
        
        if let embedding = embedding {
            XCTAssertEqual(embedding.count, 512, "If embedding is generated, it should have correct dimensions")
        } else {
            // It's acceptable for very long text to return nil if NLEmbedding can't handle it
            XCTAssertNil(embedding, "It's acceptable to return nil for problematic text")
        }
    }
    
    func testEmbeddingServiceSimilarity() {
        // Test that similar texts produce similar embeddings
        let text1 = "The cat sits on the mat"
        let text2 = "A cat is sitting on a mat"
        let text3 = "The dog runs in the park"
        
        let embedding1 = embeddingService.generateEmbedding(for: text1)
        let embedding2 = embeddingService.generateEmbedding(for: text2)
        let embedding3 = embeddingService.generateEmbedding(for: text3)
        
        XCTAssertNotNil(embedding1)
        XCTAssertNotNil(embedding2)
        XCTAssertNotNil(embedding3)
        
        if let emb1 = embedding1, let emb2 = embedding2, let emb3 = embedding3 {
            // Calculate cosine similarity
            let similarity12 = cosineSimilarity(emb1, emb2)
            let similarity13 = cosineSimilarity(emb1, emb3)
            
            // Similar texts should have higher similarity than dissimilar texts
            XCTAssertGreaterThan(similarity12, similarity13, "Similar texts should have higher cosine similarity")
        }
    }
    
    // Helper function to calculate cosine similarity
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
}