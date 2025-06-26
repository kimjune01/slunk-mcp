import Foundation

// Test the search functionality directly
@main
struct TestSearch {
    static func main() async {
        do {
            print("Initializing database...")
            let database = try SlackDatabaseSchema()
            try await database.initializeDatabase()
            
            print("Searching for messages from yesterday...")
            let formatter = ISO8601DateFormatter()
            let startDate = formatter.date(from: "2025-06-25T00:00:00Z")!
            let endDate = formatter.date(from: "2025-06-25T23:59:59Z")!
            
            let results = try await database.searchMessages(
                query: "",
                channels: nil,
                users: nil,
                startDate: startDate,
                endDate: endDate,
                limit: 5
            )
            
            print("\nFound \(results.count) messages:")
            for result in results {
                print("- [\(result.workspace)] \(result.message.sender) in \(result.message.channel): \(result.message.content.prefix(50))...")
            }
        } catch {
            print("Error: \(error)")
        }
    }
}