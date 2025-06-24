import Foundation
import NaturalLanguage

/// Comprehensive ingestion service that handles keyword extraction, embedding generation, and storage
actor SmartIngestionService {
    private var database: SQLiteVecSchema?
    private let embeddingService: EmbeddingService
    nonisolated private let keywordExtractor: KeywordExtractor
    
    init() {
        self.embeddingService = EmbeddingService()
        self.keywordExtractor = KeywordExtractor()
    }
    
    // MARK: - Configuration
    
    func setDatabase(_ database: SQLiteVecSchema) {
        self.database = database
    }
    
    // MARK: - Single Item Ingestion
    
    func ingestText(
        content: String,
        title: String,
        summary: String,
        sender: String? = nil,
        timestamp: Date? = nil,
        source: String? = nil,
        metadata: [String: Any]? = nil
    ) async throws -> IngestionResult {
        
        // Validate input
        try validateInput(content: content, title: title, summary: summary)
        
        // Extract keywords automatically
        let extractedKeywords = extractKeywords(from: content)
        
        // Create TextSummary with enhanced metadata
        let textSummary = TextSummary(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            sender: sender,
            timestamp: timestamp ?? Date(),
            source: source,
            keywords: extractedKeywords
        )
        
        // Generate embedding
        guard let embedding = embeddingService.generateEmbedding(for: textSummary.summary) else {
            throw IngestionError.embeddingGenerationFailed("Failed to generate embedding for summary")
        }
        
        // Store in database
        guard let database = database else {
            throw IngestionError.databaseNotAvailable
        }
        
        try await database.storeSummaryWithEmbedding(textSummary, embedding: embedding)
        
        return IngestionResult(
            summaryId: textSummary.id.uuidString,
            extractedKeywords: extractedKeywords,
            embeddingDimensions: embedding.count,
            processingTime: 0 // Could track actual processing time if needed
        )
    }
    
    // MARK: - Batch Ingestion
    
    func ingestBatch(_ items: [IngestionItem]) async throws -> [IngestionResult] {
        var results: [IngestionResult] = []
        
        // Process items concurrently using TaskGroup
        try await withThrowingTaskGroup(of: IngestionResult.self) { group in
            for item in items {
                group.addTask {
                    return try await self.ingestText(
                        content: item.content,
                        title: item.title,
                        summary: item.summary,
                        sender: item.sender,
                        timestamp: item.timestamp,
                        source: item.source,
                        metadata: item.metadata
                    )
                }
            }
            
            for try await result in group {
                results.append(result)
            }
        }
        
        return results
    }
    
    // MARK: - Keyword Extraction
    
    nonisolated func extractKeywords(from text: String) -> [String] {
        return keywordExtractor.extractKeywords(from: text)
    }
    
    // MARK: - Private Methods
    
    private func validateInput(content: String, title: String, summary: String) throws {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedContent.isEmpty {
            throw IngestionError.invalidInput("Content cannot be empty")
        }
        
        if trimmedTitle.isEmpty {
            throw IngestionError.invalidInput("Title cannot be empty")
        }
        
        if trimmedSummary.isEmpty {
            throw IngestionError.invalidInput("Summary cannot be empty")
        }
    }
}

// MARK: - Supporting Types

struct IngestionItem {
    let content: String
    let title: String
    let summary: String
    let sender: String?
    let timestamp: Date?
    let source: String?
    let metadata: [String: Any]?
    
    init(content: String, title: String, summary: String, sender: String? = nil, timestamp: Date? = nil, source: String? = nil, metadata: [String: Any]? = nil) {
        self.content = content
        self.title = title
        self.summary = summary
        self.sender = sender
        self.timestamp = timestamp
        self.source = source
        self.metadata = metadata
    }
}

struct IngestionResult {
    let summaryId: String
    let extractedKeywords: [String]
    let embeddingDimensions: Int
    let processingTime: TimeInterval
}

enum IngestionError: Error {
    case invalidInput(String)
    case embeddingGenerationFailed(String)
    case databaseNotAvailable
    case keywordExtractionFailed(String)
}

extension IngestionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .embeddingGenerationFailed(let message):
            return "Embedding generation failed: \(message)"
        case .databaseNotAvailable:
            return "Database is not available"
        case .keywordExtractionFailed(let message):
            return "Keyword extraction failed: \(message)"
        }
    }
}

// MARK: - Keyword Extractor

class KeywordExtractor {
    private let tagger: NLTagger
    private let stopWords: Set<String>
    
    init() {
        self.tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        
        // Common English stop words
        self.stopWords = Set([
            "a", "an", "and", "are", "as", "at", "be", "by", "for", "from",
            "has", "he", "in", "is", "it", "its", "of", "on", "that", "the",
            "to", "was", "will", "with", "the", "this", "but", "they", "have",
            "had", "what", "said", "each", "which", "she", "do", "how", "their",
            "if", "up", "out", "many", "then", "them", "these", "so", "some",
            "her", "would", "make", "like", "into", "him", "time", "two", "more",
            "go", "no", "way", "could", "my", "than", "first", "been", "call",
            "who", "oil", "its", "now", "find", "long", "down", "day", "did",
            "get", "come", "made", "may", "part"
        ])
    }
    
    func extractKeywords(from text: String) -> [String] {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return [] }
        
        tagger.string = trimmedText
        
        var keywords: [String] = []
        var keywordCounts: [String: Int] = [:]
        
        // Extract named entities
        let entityTags = tagger.tags(in: trimmedText.startIndex..<trimmedText.endIndex,
                                   unit: .word,
                                   scheme: .nameType,
                                   options: [.omitWhitespace, .omitPunctuation])
        
        for (tag, range) in entityTags {
            if let tag = tag, tag == .personalName || tag == .placeName || tag == .organizationName {
                let entity = String(trimmedText[range]).lowercased()
                if !stopWords.contains(entity) && entity.count > 2 {
                    keywordCounts[entity, default: 0] += 1
                }
            }
        }
        
        // Extract important nouns and adjectives
        let lexicalTags = tagger.tags(in: trimmedText.startIndex..<trimmedText.endIndex,
                                    unit: .word,
                                    scheme: .lexicalClass,
                                    options: [.omitWhitespace, .omitPunctuation])
        
        for (tag, range) in lexicalTags {
            if let tag = tag, tag == .noun || tag == .adjective {
                let word = String(trimmedText[range]).lowercased()
                if !stopWords.contains(word) && word.count > 2 {
                    keywordCounts[word, default: 0] += 1
                }
            }
        }
        
        // Sort by frequency and take top keywords
        let sortedKeywords = keywordCounts.sorted { $0.value > $1.value }
        let maxKeywords = min(10, sortedKeywords.count) // Limit to top 10 keywords
        
        for i in 0..<maxKeywords {
            keywords.append(sortedKeywords[i].key)
        }
        
        return keywords
    }
}