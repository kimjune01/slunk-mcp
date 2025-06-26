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
    
    func testNLEmbeddingGeneration() async throws {
        // Should generate 512-dimension vector for text
        let text = "This is a test sentence for embedding generation."
        let embedding = try await embeddingService.generateEmbedding(for: text)
        
        XCTAssertEqual(embedding.count, 512, "Should generate 512-dimension vector")
        
        // Vector values should be within reasonable range for normalized embeddings
        for value in embedding {
            XCTAssertTrue(value >= -1.0 && value <= 1.0, "Embedding values should be normalized between -1 and 1")
        }
    }
    
    func testNLEmbeddingWithEmptyText() async {
        // Should throw error for empty text
        let emptyText = ""
        
        do {
            let _ = try await embeddingService.generateEmbedding(for: emptyText)
            XCTFail("Should throw error for empty text")
        } catch {
            // Expected to throw error
            XCTAssertTrue(true, "Correctly throws error for empty text")
        }
        
        // Should also throw error for whitespace-only text
        let whitespaceText = "   \n\t  "
        
        do {
            let _ = try await embeddingService.generateEmbedding(for: whitespaceText)
            XCTFail("Should throw error for whitespace-only text")
        } catch {
            // Expected to throw error
            XCTAssertTrue(true, "Correctly throws error for whitespace-only text")
        }
    }
    
    func testNLEmbeddingConsistency() async throws {
        // Should be consistent for same input
        let text = "Consistent embedding test text"
        let embedding1 = try await embeddingService.generateEmbedding(for: text)
        let embedding2 = try await embeddingService.generateEmbedding(for: text)
        
        XCTAssertEqual(embedding1.count, embedding2.count)
        
        // Embeddings should be identical for the same input
        for (index, value) in embedding1.enumerated() {
            XCTAssertEqual(value, embedding2[index], accuracy: 0.0001, "Embeddings should be consistent for same input")
        }
    }
    
    func testEmbeddingServiceBatchProcessing() async throws {
        // Should handle batch processing
        let texts = [
            "First test sentence",
            "Second test sentence", 
            "Third test sentence"
        ]
        
        var embeddings: [[Float]] = []
        for text in texts {
            let embedding = try await embeddingService.generateEmbedding(for: text)
            embeddings.append(embedding)
        }
        
        XCTAssertEqual(embeddings.count, texts.count, "Should return embedding for each input text")
        
        for embedding in embeddings {
            XCTAssertEqual(embedding.count, 512, "Each embedding should have 512 dimensions")
        }
    }
    
    func testEmbeddingServiceValidation() async {
        // Should validate input text
        let validTexts = ["Valid text", "Another valid text"]
        let invalidTexts = ["", "   ", "\n\t"]
        
        // Valid texts should generate embeddings
        for validText in validTexts {
            do {
                let embedding = try await embeddingService.generateEmbedding(for: validText)
                XCTAssertEqual(embedding.count, 512, "Valid text should generate 512-dimensional embedding")
            } catch {
                XCTFail("Valid text should not throw error: \(error)")
            }
        }
        
        // Invalid texts should throw errors
        for invalidText in invalidTexts {
            do {
                let _ = try await embeddingService.generateEmbedding(for: invalidText)
                XCTFail("Invalid text '\(invalidText)' should throw error")
            } catch {
                // Expected to throw error
                XCTAssertTrue(true, "Correctly throws error for invalid text '\(invalidText)'")
            }
        }
    }
    
    func testEmbeddingServiceErrorHandling() async {
        // Should handle NLEmbedding failures gracefully
        // Test with extremely long text that might cause issues
        let veryLongText = String(repeating: "This is a very long text that might cause embedding generation issues. ", count: 1000)
        
        // Should not crash and should either return a valid embedding or handle error gracefully
        do {
            let embedding = try await embeddingService.generateEmbedding(for: veryLongText)
            XCTAssertEqual(embedding.count, 512, "If embedding is generated, it should have correct dimensions")
        } catch {
            // It's acceptable for very long text to throw an error if NLEmbedding can't handle it
            XCTAssertTrue(true, "It's acceptable to throw error for problematic text")
        }
    }
    
    func testEmbeddingServiceSimilarity() async throws {
        // Test that similar texts produce similar embeddings
        let text1 = "The cat sits on the mat"
        let text2 = "A cat is sitting on a mat"
        let text3 = "The dog runs in the park"
        
        let embedding1 = try await embeddingService.generateEmbedding(for: text1)
        let embedding2 = try await embeddingService.generateEmbedding(for: text2)
        let embedding3 = try await embeddingService.generateEmbedding(for: text3)
        
        // Calculate cosine similarity
        let similarity12 = cosineSimilarity(embedding1, embedding2)
        let similarity13 = cosineSimilarity(embedding1, embedding3)
        
        // Similar texts should have higher similarity than dissimilar texts
        XCTAssertGreaterThan(similarity12, similarity13, "Similar texts should have higher cosine similarity")
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