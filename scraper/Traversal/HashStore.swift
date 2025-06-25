//
//  HashStore.swift
//  observer-lib
//
//  Created by June Kim on 2024-11-13.
//
import Foundation

public class HashStore {
    var store = Set<Int>()
    var lastMonthStore = Set<Int>()
    public nonisolated(unsafe) static let shared = HashStore()

    init() {
        cleanOldFiles()
        loadStores()
    }

    public func loadStores() {
        let currentFileURL = self.getFileURL()
        let lastMonthFileURL = self.getLastMonthFileURL()

        // Load current month's store
        do {
            let data = try Data(contentsOf: currentFileURL)
            store = try JSONDecoder().decode(Set<Int>.self, from: data)
        } catch {
            store = Set()
        }

        // Load last month's store
        do {
            let data = try Data(contentsOf: lastMonthFileURL)
            lastMonthStore = try JSONDecoder().decode(Set<Int>.self, from: data)
        } catch {
            lastMonthStore = Set()
        }
    }

    public func insert(_ hash: Int) {
        store.insert(hash)
        saveStoreAsync()
    }

    private func saveStoreAsync() {
        let fileURL = getFileURL()
        do {
            let data = try JSONEncoder().encode(store)
            try data.write(to: fileURL)
        } catch {
            print("Error saving hashes: \(error)")
        }
    }

    private func getFileURL() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM"
        let fileName = "GenOSMessageHashStore-\(dateFormatter.string(from: Date())).json"

        // Create the GenOS directory in the temporary directory
        let genOSDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("GenOS")
        try? FileManager.default.createDirectory(at: genOSDirectory, withIntermediateDirectories: true, attributes: nil)

        return genOSDirectory.appendingPathComponent(fileName)
    }

    private func getLastMonthFileURL() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM"
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let fileName = "GenOSMessageHashStore-\(dateFormatter.string(from: lastMonth)).json"

        // Create the GenOS directory in the temporary directory
        let genOSDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("GenOS")
        try? FileManager.default.createDirectory(at: genOSDirectory, withIntermediateDirectories: true, attributes: nil)

        return genOSDirectory.appendingPathComponent(fileName)
    }

    // provide date for testing
    func cleanOldFiles(currentDate: Date = Date()) {
        let fileManager = FileManager.default
        let genOSDirectory = fileManager.temporaryDirectory.appendingPathComponent("GenOS")

        do {
            let files = try fileManager.contentsOfDirectory(at: genOSDirectory, includingPropertiesForKeys: nil)
            let twoMonthsAgo = currentDate.addingTimeInterval(-60 * 60 * 24 * 60) // Two months ago

            for file in files {
                if let creationDate = try? fileManager.attributesOfItem(atPath: file.path)[.creationDate] as? Date {
                    if creationDate < twoMonthsAgo {
                        try fileManager.removeItem(at: file)
                        print("Deleted old file: \(file.lastPathComponent)")
                    }
                }
            }
        } catch {
            print("Error cleaning old files: \(error)")
        }
    }

    public func contains(_ hash: Int) -> Bool {
        store.contains(hash) || lastMonthStore.contains(hash)
    }

    public func filterForUnique<T: Hashable>(_ hashable: T) -> T? {
        let hash = hashable.hashValue
        if store.contains(hash) {
            return nil
        } else if lastMonthStore.contains(hash) {
            return nil
        } else {
            store.formUnion([hash])
            return hashable
        }
    }

    public func resetStore() {
        store.removeAll()
        saveStoreAsync() // Save after resetting
    }
}
