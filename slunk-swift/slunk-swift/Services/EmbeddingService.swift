import Foundation
import NaturalLanguage

public class EmbeddingService {
    private let nlEmbedding: NLEmbedding?
    
    public init() {
        // Initialize with sentence embeddings - this provides embeddings
        self.nlEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    }
    
    // MARK: - Single Text Embedding
    
    public func generateEmbedding(for text: String) async throws -> [Float] {
        // Validate input text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw EmbeddingServiceError.emptyText
        }
        
        // Check if NLEmbedding is available
        guard let nlEmbedding = self.nlEmbedding else {
            throw EmbeddingServiceError.embeddingGenerationFailed("NLEmbedding not available")
        }
        
        // Generate embedding using NLEmbedding
        guard let embedding = nlEmbedding.vector(for: trimmedText) else {
            throw EmbeddingServiceError.embeddingGenerationFailed("Failed to generate embedding for text")
        }
        
        // Convert from [Double] to [Float] and ensure proper dimensions
        let floatEmbedding = embedding.map { Float($0) }
        guard floatEmbedding.count == 512 else {
            throw EmbeddingServiceError.invalidDimensions(floatEmbedding.count)
        }
        
        return floatEmbedding
    }
    
    // MARK: - Batch Processing
    
    public func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
        var embeddings: [[Float]] = []
        for text in texts {
            let embedding = try await generateEmbedding(for: text)
            embeddings.append(embedding)
        }
        return embeddings
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