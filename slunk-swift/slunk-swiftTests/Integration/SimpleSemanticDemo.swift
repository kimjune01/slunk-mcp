import XCTest
import Foundation
import NaturalLanguage
@testable import slunk_swift

final class SimpleSemanticDemo: XCTestCase {
    
    func testSimpleSemanticSimilarity() async throws {
        print("\n🔬 Simple Semantic Similarity Demonstration")
        print(String(repeating: "=", count: 50))
        
        let embeddingService = EmbeddingService()
        
        // Test phrases with different levels of semantic similarity
        let testPhrases = [
            "Swift programming language",
            "concurrent programming patterns", 
            "async await programming",
            "database performance optimization",
            "machine learning models",
            "cooking Italian pasta"
        ]
        
        print("\n📊 Generating embeddings for test phrases...")
        var embeddings: [(String, [Float])] = []
        
        for phrase in testPhrases {
            do {
                let embedding = try await embeddingService.generateEmbedding(for: phrase)
                embeddings.append((phrase, embedding))
                print("  ✓ \(phrase) → [\(embedding.count) dimensions]")
            } catch {
                print("  ❌ Failed to generate embedding for '\(phrase)': \(error)")
                continue
            }
        }
        
        print("\n🎯 Computing semantic similarities...")
        
        // Compare the first phrase with all others
        let referencePhrase = embeddings[0].0
        let referenceEmbedding = embeddings[0].1
        
        print("\nReference: '\(referencePhrase)'")
        print("Similarities:")
        
        for (phrase, embedding) in embeddings {
            let similarity = cosineSimilarity(referenceEmbedding, embedding)
            let percentage = Int(similarity * 100)
            
            // Create visual similarity bar
            let barLength = Int(similarity * 20)
            let bar = String(repeating: "█", count: barLength) + String(repeating: "░", count: 20 - barLength)
            
            print("  \(bar) \(percentage)% - \(phrase)")
            
            if phrase != referencePhrase {
                // Validate that programming-related content has higher similarity
                if phrase.contains("programming") || phrase.contains("async") {
                    XCTAssertGreaterThan(similarity, 0.3, "Programming-related content should have moderate similarity")
                } else if phrase.contains("cooking") {
                    XCTAssertLessThan(similarity, 0.5, "Unrelated content should have lower similarity")
                }
            }
        }
        
        print("\n🧪 Testing specific semantic relationships...")
        
        // Test that programming concepts cluster together
        let programmingPhrases = [
            "Swift programming language",
            "concurrent programming patterns",
            "async await programming"
        ]
        
        var programmingSimilarities: [Double] = []
        
        for i in 0..<programmingPhrases.count {
            for j in (i+1)..<programmingPhrases.count {
                do {
                    let emb1 = try await embeddingService.generateEmbedding(for: programmingPhrases[i])
                    let emb2 = try await embeddingService.generateEmbedding(for: programmingPhrases[j])
                    let similarity = cosineSimilarity(emb1, emb2)
                    programmingSimilarities.append(similarity)
                    print("  '\(programmingPhrases[i])' ↔ '\(programmingPhrases[j])': \(Int(similarity * 100))%")
                } catch {
                    print("  ❌ Failed to compare embeddings: \(error)")
                    continue
                }
            }
        }
        
        // Validate that programming concepts are semantically similar
        let avgProgrammingSimilarity = programmingSimilarities.reduce(0, +) / Double(programmingSimilarities.count)
        print("\n📈 Average programming concept similarity: \(Int(avgProgrammingSimilarity * 100))%")
        
        XCTAssertGreaterThan(avgProgrammingSimilarity, 0.3, "Programming concepts should have moderate semantic similarity")
        
        print("\n✅ Semantic similarity working correctly!")
        print("🎯 Vector embeddings successfully capture semantic relationships")
    }
    
    // MARK: - Helper Functions
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count else { return 0.0 }
        
        let dotProduct = zip(a, b).map { Double($0.0) * Double($0.1) }.reduce(0, +)
        let magnitudeA = sqrt(a.map { Double($0) * Double($0) }.reduce(0, +))
        let magnitudeB = sqrt(b.map { Double($0) * Double($0) }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
}

// String multiplication operator removed to avoid conflicts