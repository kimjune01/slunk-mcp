import Foundation
import SQLite3
import GRDB

struct ButtonAction {
    static func perform() {
        do {
            try HistoryDatabase.setup()
            guard let dbQueue = HistoryDatabase.dbQueue else {
                return
            }
            
            let newHistory = History(id: nil, text: "Hello, SQLite via GRDB!")
            try dbQueue.write { db in
                try newHistory.insert(db)
            }
            
            let allHistory: [History] = try dbQueue.read { db in
                try History.fetchAll(db)
            }
            
            try dbQueue.write { db in
                _ = try History.deleteAll(db)
            }
        } catch {
            // Database test failed
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