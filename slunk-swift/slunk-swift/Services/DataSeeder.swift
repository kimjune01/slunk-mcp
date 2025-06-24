import Foundation

/// Handles automatic seeding of sample conversation data into the vector database
actor DataSeeder {
    private var database: SQLiteVecSchema?
    private let smartIngestion: SmartIngestionService
    
    init() {
        self.smartIngestion = SmartIngestionService()
    }
    
    // MARK: - Configuration
    
    func setDatabase(_ database: SQLiteVecSchema) async {
        self.database = database
        await smartIngestion.setDatabase(database)
    }
    
    // MARK: - Seeding Operations
    
    func seedIfEmpty() async throws -> SeedingResult {
        guard let database = database else {
            throw SeedingError.databaseNotAvailable
        }
        
        let startTime = Date()
        
        // Check if database already has data
        let existingCount = try await database.getTotalSummaryCount()
        if existingCount > 0 {
            return SeedingResult(
                wasSeeded: false,
                itemsSeeded: 0,
                processingTime: Date().timeIntervalSince(startTime)
            )
        }
        
        // Load sample data and seed database
        let sampleData = loadSampleConversations()
        var itemsSeeded = 0
        
        for sample in sampleData {
            do {
                let _ = try await smartIngestion.ingestText(
                    content: sample.content,
                    title: sample.title,
                    summary: sample.summary,
                    sender: sample.sender,
                    timestamp: sample.timestamp
                )
                itemsSeeded += 1
            } catch {
                print("Warning: Failed to seed sample conversation '\(sample.title)': \(error)")
                // Continue with other items rather than failing completely
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return SeedingResult(
            wasSeeded: true,
            itemsSeeded: itemsSeeded,
            processingTime: processingTime
        )
    }
    
    func forceSeed() async throws -> SeedingResult {
        guard database != nil else {
            throw SeedingError.databaseNotAvailable
        }
        
        let startTime = Date()
        let sampleData = loadSampleConversations()
        var itemsSeeded = 0
        
        for sample in sampleData {
            do {
                let _ = try await smartIngestion.ingestText(
                    content: sample.content,
                    title: sample.title,
                    summary: sample.summary,
                    sender: sample.sender,
                    timestamp: sample.timestamp
                )
                itemsSeeded += 1
            } catch {
                print("Warning: Failed to seed sample conversation '\(sample.title)': \(error)")
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return SeedingResult(
            wasSeeded: true,
            itemsSeeded: itemsSeeded,
            processingTime: processingTime
        )
    }
    
    // MARK: - Sample Data Loading
    
    private func loadSampleConversations() -> [SampleConversation] {
        // Try to load from bundle first
        if let bundleData = loadFromBundle() {
            return bundleData
        }
        
        // Fall back to embedded data
        return createEmbeddedSampleData()
    }
    
    private func loadFromBundle() -> [SampleConversation]? {
        guard let url = Bundle.main.url(forResource: "sample_conversations", withExtension: "json") else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let conversations = try JSONDecoder().decode([SampleConversation].self, from: data)
            return conversations
        } catch {
            print("Warning: Failed to load sample conversations from bundle: \(error)")
            return nil
        }
    }
    
    private func createEmbeddedSampleData() -> [SampleConversation] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            SampleConversation(
                title: "Swift Concurrency Best Practices",
                content: """
                Had an excellent discussion about Swift's structured concurrency model. We covered async/await patterns, TaskGroup usage for parallel processing, and proper error handling in asynchronous contexts. The team particularly appreciated the explanation of actor isolation and how it prevents data races. We also discussed MainActor usage for UI updates and the importance of avoiding blocking the main thread. Overall, everyone felt more confident about implementing concurrent features in our iOS apps.
                """,
                summary: "Comprehensive discussion about Swift concurrency patterns, async/await, TaskGroup, actor isolation, and MainActor usage",
                sender: "Alice",
                timestamp: calendar.date(byAdding: .day, value: -1, to: now)!,
                keywords: ["swift", "concurrency", "async", "await", "taskgroup", "actor", "mainactor", "ios"]
            ),
            
            SampleConversation(
                title: "iOS Architecture and SwiftUI Integration",
                content: """
                Reviewed our transition from UIKit to SwiftUI and discussed architectural patterns. We implemented MVVM with proper data binding, explored Combine for reactive programming, and set up a clean navigation system. The conversation covered state management strategies, including @State, @StateObject, and @ObservedObject usage patterns. We also discussed performance considerations when building complex SwiftUI views and the importance of proper view lifecycle management.
                """,
                summary: "iOS architecture review covering SwiftUI, MVVM, Combine, state management, and performance optimization",
                sender: "Bob",
                timestamp: calendar.date(byAdding: .day, value: -3, to: now)!,
                keywords: ["ios", "swiftui", "mvvm", "combine", "architecture", "state", "performance", "navigation"]
            ),
            
            SampleConversation(
                title: "Vector Database Performance Analysis",
                content: """
                Analyzed the performance characteristics of our vector database implementation. We examined SQLiteVec query performance, embedding generation speed, and memory usage patterns. The discussion covered indexing strategies for similarity search, batch processing optimizations, and cache implementation for frequently accessed vectors. We identified several bottlenecks and proposed solutions including query optimization, connection pooling, and background processing strategies.
                """,
                summary: "Performance analysis of vector database including SQLiteVec optimization, indexing, and caching strategies",
                sender: "Carol",
                timestamp: calendar.date(byAdding: .weekOfYear, value: -1, to: now)!,
                keywords: ["database", "vector", "performance", "sqlitevec", "indexing", "optimization", "cache", "embeddings"]
            ),
            
            SampleConversation(
                title: "Machine Learning Integration Strategy",
                content: """
                Explored various approaches for integrating machine learning capabilities into our mobile applications. We discussed Core ML model optimization, on-device inference performance, and the trade-offs between cloud-based and edge computing. The conversation covered natural language processing with Apple's NLTagger, custom model training workflows, and deployment strategies. We also addressed privacy considerations and data handling best practices for ML features.
                """,
                summary: "Machine learning integration covering Core ML, on-device inference, NLP, and privacy considerations",
                sender: "David",
                timestamp: calendar.date(byAdding: .day, value: -5, to: now)!,
                keywords: ["machine learning", "core ml", "inference", "nlp", "nltagger", "privacy", "mobile", "ai"]
            ),
            
            SampleConversation(
                title: "MCP Server Architecture Discussion",
                content: """
                Deep dive into Model Context Protocol (MCP) server implementation. We covered JSON-RPC 2.0 compliance, tool registration patterns, and error handling strategies. The discussion included stdio transport optimization, concurrent request handling, and integration with various AI assistants. We also explored extension patterns for custom tools and the importance of proper protocol documentation for client implementations.
                """,
                summary: "MCP server architecture discussion covering JSON-RPC, tool registration, and protocol compliance",
                sender: "Eve",
                timestamp: calendar.date(byAdding: .day, value: -7, to: now)!,
                keywords: ["mcp", "json-rpc", "protocol", "server", "tools", "stdio", "ai", "assistant"]
            ),
            
            SampleConversation(
                title: "User Experience Design Workshop",
                content: """
                Conducted a comprehensive UX design workshop focusing on conversational interfaces and natural language interaction patterns. We explored information architecture for chat-based systems, progressive disclosure techniques, and accessibility considerations. The session covered user mental models for AI-assisted workflows, error recovery patterns, and feedback mechanisms. Participants created wireframes for various interaction scenarios and discussed testing strategies for conversational UX.
                """,
                summary: "UX design workshop on conversational interfaces, accessibility, user mental models, and testing strategies",
                sender: "Frank",
                timestamp: calendar.date(byAdding: .day, value: -10, to: now)!,
                keywords: ["ux", "design", "conversation", "accessibility", "interface", "testing", "wireframes", "workflow"]
            ),
            
            SampleConversation(
                title: "Testing Strategy for Async Code",
                content: """
                Developed comprehensive testing strategies for asynchronous Swift code. We covered XCTest async/await testing patterns, mock implementation for concurrent systems, and performance testing for async operations. The discussion included test isolation techniques, race condition detection, and proper teardown for async resources. We also explored continuous integration setup for async tests and debugging strategies for concurrent code failures.
                """,
                summary: "Testing strategies for async Swift code including XCTest patterns, mocking, and CI setup",
                sender: "Grace",
                timestamp: calendar.date(byAdding: .day, value: -12, to: now)!,
                keywords: ["testing", "async", "swift", "xctest", "mock", "ci", "debugging", "concurrent"]
            ),
            
            SampleConversation(
                title: "Security and Privacy Implementation",
                content: """
                Reviewed security and privacy requirements for our application ecosystem. We discussed data encryption strategies, keychain integration, and secure communication protocols. The conversation covered App Transport Security configuration, certificate pinning implementation, and biometric authentication patterns. We also addressed GDPR compliance requirements, data minimization principles, and user consent management systems.
                """,
                summary: "Security and privacy review covering encryption, keychain, ATS, biometrics, and GDPR compliance",
                sender: "Helen",
                timestamp: calendar.date(byAdding: .weekOfYear, value: -2, to: now)!,
                keywords: ["security", "privacy", "encryption", "keychain", "biometric", "gdpr", "compliance", "protocol"]
            )
        ]
    }
}

// MARK: - Supporting Types

struct SampleConversation: Codable {
    let title: String
    let content: String
    let summary: String
    let sender: String
    let timestamp: Date
    let keywords: [String]
}

struct SeedingResult {
    let wasSeeded: Bool
    let itemsSeeded: Int
    let processingTime: TimeInterval
}

enum SeedingError: Error {
    case databaseNotAvailable
    case seedingFailed(String)
}

extension SeedingError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .databaseNotAvailable:
            return "Database is not available for seeding"
        case .seedingFailed(let message):
            return "Seeding failed: \(message)"
        }
    }
}