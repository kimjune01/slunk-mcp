import Foundation

// Test the improved deduplication mechanism
@main
struct TestDeduplication {
    static func main() async {
        do {
            print("Testing improved deduplication mechanism...")
            
            // Create database
            let database = try SlackDatabaseSchema()
            try await database.initializeDatabase()
            
            // Create test messages with same content but different timestamps
            let baseTimestamp = Date()
            let workspace = "TestWorkspace"
            let channel = "test-channel"
            let sender = "TestUser"
            let content = "This is a test message for deduplication"
            
            // Create multiple messages with same content but different timestamps
            let messages: [SlackMessage] = (0..<5).map { i in
                SlackMessage(
                    id: "\(baseTimestamp.timeIntervalSince1970 + Double(i))",
                    timestamp: baseTimestamp.addingTimeInterval(Double(i)),
                    sender: sender,
                    content: content,
                    channel: channel
                )
            }
            
            print("\nProcessing \(messages.count) messages with identical content...")
            
            var results: [(message: SlackMessage, result: DeduplicationResult)] = []
            
            // Process each message
            for message in messages {
                let result = try await database.processMessage(message, workspace: workspace, channel: channel)
                results.append((message, result))
                
                // Print result
                switch result {
                case .new(let id):
                    print("✅ Message \(message.id): NEW (id: \(id))")
                case .duplicate:
                    print("❌ Message \(message.id): DUPLICATE")
                case .updated(let id):
                    print("📝 Message \(message.id): UPDATED (id: \(id))")
                case .reactionsUpdated(let id):
                    print("🙂 Message \(message.id): REACTIONS UPDATED (id: \(id))")
                }
            }
            
            // Check deduplication effectiveness
            let newCount = results.filter { 
                if case .new(_) = $0.result { return true }
                return false
            }.count
            
            let duplicateCount = results.filter { 
                if case .duplicate = $0.result { return true }
                return false
            }.count
            
            print("\n📊 Deduplication Results:")
            print("   Total messages: \(messages.count)")
            print("   New messages: \(newCount)")
            print("   Duplicates: \(duplicateCount)")
            print("   Deduplication rate: \(String(format: "%.1f%%", Double(duplicateCount) / Double(messages.count) * 100))")
            
            // Verify content hashes
            print("\n🔍 Content Hash Analysis:")
            for message in messages {
                print("   Message \(message.id):")
                print("     Deduplication Key: \(message.deduplicationKey)")
                print("     Content Hash: \(message.contentHash)")
            }
            
            // Query database to verify
            let storedMessages = try await database.searchMessages(
                query: content,
                channels: [channel],
                users: [sender],
                limit: 10
            )
            
            print("\n📦 Messages in database: \(storedMessages.count)")
            for stored in storedMessages {
                print("   ID: \(stored.message.id), Content: \(stored.message.content.prefix(30))...")
            }
            
            print("\n✅ Deduplication test complete!")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
}

// Extension to make it compile standalone
extension Date {
    func addingTimeInterval(_ timeInterval: TimeInterval) -> Date {
        return Date(timeIntervalSince1970: self.timeIntervalSince1970 + timeInterval)
    }
}