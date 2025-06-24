import Foundation
import NaturalLanguage

class EmbeddingService {
    private let nlEmbedding: NLEmbedding?
    
    init() {
        // Initialize with sentence embeddings - this provides embeddings
        self.nlEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    }
    
    // MARK: - Single Text Embedding
    
    func generateEmbedding(for text: String) -> [Float]? {
        // Validate input text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }
        
        // Check if NLEmbedding is available
        guard let nlEmbedding = self.nlEmbedding else {
            print("EmbeddingService: NLEmbedding not available")
            return nil
        }
        
        // Generate embedding using NLEmbedding
        guard let embedding = nlEmbedding.vector(for: trimmedText) else {
            print("EmbeddingService: Failed to generate embedding for text")
            return nil
        }
        
        // Convert from [Double] to [Float]
        return embedding.map { Float($0) }
    }
    
    // MARK: - Batch Processing
    
    func generateEmbeddings(for texts: [String]) -> [([Float]?)] {
        return texts.map { generateEmbedding(for: $0) }
    }
}

// MARK: - Error Types

enum EmbeddingServiceError: Error, Equatable {
    case emptyText
    case embeddingGenerationFailed(String)
    case invalidDimensions(Int)
}

extension EmbeddingServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Text cannot be empty"
        case .embeddingGenerationFailed(let message):
            return "Failed to generate embedding: \(message)"
        case .invalidDimensions(let dimensions):
            return "Invalid embedding dimensions: \(dimensions), expected 512"
        }
    }
}