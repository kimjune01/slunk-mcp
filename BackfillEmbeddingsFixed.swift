#!/usr/bin/env swift

import Foundation
import NaturalLanguage
import SQLite3

// Standalone Swift script to backfill embeddings
class EmbeddingBackfill {
    private var db: OpaquePointer?
    private let nlEmbedding: NLEmbedding?
    
    init() {
        // Initialize with sentence embeddings
        self.nlEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    }
    
    func run() {
        print("🚀 Starting embedding backfill...")
        
        // Get database path
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = appSupport.appendingPathComponent("Slunk/slack_store.db").path
        
        print("📁 Database path: \(dbPath)")
        
        // Check if database exists
        guard FileManager.default.fileExists(atPath: dbPath) else {
            print("❌ Database not found at \(dbPath)")
            return
        }
        
        // Open database
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ Unable to open database")
            return
        }
        
        defer {
            sqlite3_close(db)
        }
        
        // Check current status
        let (messageCount, embeddingCount) = getCurrentStatus()
        print("\n📊 Current status:")
        print("   Total messages: \(messageCount)")
        print("   Messages with embeddings: \(embeddingCount)")
        print("   Messages needing embeddings: \(messageCount - embeddingCount)")
        
        if messageCount == embeddingCount && messageCount > 0 {
            print("\n✅ All messages already have embeddings!")
            return
        }
        
        // Check if NLEmbedding is available
        guard let nlEmbedding = self.nlEmbedding else {
            print("❌ NLEmbedding not available")
            return
        }
        
        print("\n🔍 Testing NLEmbedding...")
        if let testEmbedding = nlEmbedding.vector(for: "test") {
            print("   ✅ NLEmbedding working, dimensions: \(testEmbedding.count)")
        }
        
        // Process messages in batches
        var processedCount = 0
        var failedCount = 0
        let batchSize = 100
        
        while true {
            let messages = getMessagesWithoutEmbeddings(limit: batchSize)
            
            if messages.isEmpty {
                break
            }
            
            print("\n🔄 Processing batch of \(messages.count) messages...")
            
            for (messageId, content) in messages {
                autoreleasepool {
                    // Generate embedding
                    if let embedding = nlEmbedding.vector(for: content) {
                        // Convert to Float array
                        let floatEmbedding = embedding.map { Float($0) }
                        
                        if floatEmbedding.count == 512 {
                            // Store embedding
                            if storeEmbedding(messageId: messageId, embedding: floatEmbedding) {
                                processedCount += 1
                                if processedCount % 10 == 0 {
                                    print("   Processed \(processedCount) messages...")
                                }
                            } else {
                                print("⚠️  Failed to store embedding for message \(messageId)")
                                failedCount += 1
                            }
                        } else {
                            print("⚠️  Dimension mismatch for message \(messageId): got \(floatEmbedding.count), expected 512")
                            failedCount += 1
                        }
                    } else {
                        print("⚠️  Failed to generate embedding for message \(messageId)")
                        failedCount += 1
                    }
                }
            }
        }
        
        // Final status
        let (finalMessageCount, finalEmbeddingCount) = getCurrentStatus()
        
        print("\n✅ Backfill complete!")
        print("   Processed: \(processedCount) messages")
        print("   Failed: \(failedCount) messages")
        print("   Total embeddings now: \(finalEmbeddingCount) / \(finalMessageCount)")
    }
    
    private func getCurrentStatus() -> (messages: Int, embeddings: Int) {
        var messageCount = 0
        var embeddingCount = 0
        
        // Count messages
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM slack_messages", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                messageCount = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        
        // Count embeddings - using direct count on vec0 table
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM slack_message_embeddings", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                embeddingCount = Int(sqlite3_column_int(stmt, 0))
            } else {
                print("⚠️  Error stepping embeddings count: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("⚠️  Error preparing embeddings count: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        
        return (messageCount, embeddingCount)
    }
    
    private func getMessagesWithoutEmbeddings(limit: Int) -> [(id: String, content: String)] {
        var messages: [(String, String)] = []
        
        let sql = """
            SELECT sm.id, sm.content 
            FROM slack_messages sm
            LEFT JOIN slack_message_embeddings sme ON sm.id = sme.message_id
            WHERE sme.message_id IS NULL 
            AND sm.content IS NOT NULL 
            AND sm.content != ''
            LIMIT ?
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let idCStr = sqlite3_column_text(stmt, 0),
                   let contentCStr = sqlite3_column_text(stmt, 1) {
                    let id = String(cString: idCStr)
                    let content = String(cString: contentCStr)
                    messages.append((id, content))
                }
            }
        } else {
            print("⚠️  Error preparing message query: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        
        return messages
    }
    
    private func storeEmbedding(messageId: String, embedding: [Float]) -> Bool {
        // For vec0 virtual table, we need to use the proper format
        let sql = "INSERT INTO slack_message_embeddings (message_id, embedding) VALUES (?, vec_f32(?))"
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("⚠️  Error preparing insert: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        defer { sqlite3_finalize(stmt) }
        
        // Bind message ID
        sqlite3_bind_text(stmt, 1, messageId, -1, nil)
        
        // Convert Float array to Data
        let embeddingData = embedding.withUnsafeBytes { Data($0) }
        
        // Bind embedding data as blob
        let result = embeddingData.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 2, bytes.baseAddress, Int32(embeddingData.count), SQLITE_TRANSIENT)
        }
        
        if result != SQLITE_OK {
            print("⚠️  Error binding blob: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        let stepResult = sqlite3_step(stmt)
        if stepResult != SQLITE_DONE {
            print("⚠️  Error executing insert: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        return true
    }
}

// Run the backfill
let backfill = EmbeddingBackfill()
backfill.run()