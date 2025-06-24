import Foundation
import SQLite3
import GRDB

struct ButtonAction {
    static func perform() {
        print("Button action triggered!")
        do {
            print("Setting up database...")
            try HistoryDatabase.setup()
            guard let dbQueue = HistoryDatabase.dbQueue else {
                print("Database queue not available.")
                return
            }
            print("Inserting a new history row...")
            let newHistory = History(id: nil, text: "Hello, SQLite via GRDB!")
            try dbQueue.write { db in
                try newHistory.insert(db)
            }
            print("Inserted row. Now fetching all rows...")
            let allHistory: [History] = try dbQueue.read { db in
                try History.fetchAll(db)
            }
            print("Fetched rows:")
            for history in allHistory {
                print("id: \(history.id ?? -1), text: \(history.text)")
            }
            print("Now deleting all rows from history table...")
            try dbQueue.write { db in
                _ = try History.deleteAll(db)
            }
            print("All rows deleted. Round trip complete.")
        } catch {
            print("Error during round trip: \(error)")
        }
    }
}

struct History: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var text: String
}

struct HistoryDatabase {
    static var dbQueue: DatabaseQueue?

    static func setup() throws {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsURL = urls.first else { return }
        let databaseURL = documentsURL.appendingPathComponent("history-grdb.sqlite")
        dbQueue = try DatabaseQueue(path: databaseURL.path)

        var migrator = DatabaseMigrator()
        migrator.registerMigration("createHistory") { db in
            try db.create(table: "history") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("text", .text)
            }
        }
        try migrator.migrate(dbQueue!)
    }
} 