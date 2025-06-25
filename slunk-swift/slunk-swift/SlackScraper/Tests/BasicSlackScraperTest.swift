import Foundation

/// Basic test functionality for refactored SlackScraper
public struct SlackScraperTests {
    
    public static func runAllTests() async -> Bool {
        print("🧪 Running Complete SlackScraper Tests...")
        
        var allTestsPassed = true
        
        // Phase 1 Tests (Original)
        print("\n=== Phase 1 Tests ===")
        allTestsPassed = runDataModelTests() && allTestsPassed
        allTestsPassed = await runServiceTests() && allTestsPassed
        allTestsPassed = runContentProcessingTests() && allTestsPassed
        allTestsPassed = runProtocolTests() && allTestsPassed
        
        // Phase 2 Tests (New)
        print("\n=== Phase 2 Tests ===")
        print("⏰ DeadlineManager tests skipped (using LBAccessibility framework)")
        print("🏷️ ElementMatchers tests skipped (using LBAccessibility framework)")
        allTestsPassed = await AccessibilityCoreTests.runAllTests() && allTestsPassed
        allTestsPassed = await SlackUIParserTests.runAllTests() && allTestsPassed
        
        print("\n📊 Complete Test Summary")
        print("All tests passed: \(allTestsPassed ? "✅ YES" : "❌ NO")")
        
        return allTestsPassed
    }
    
    // MARK: - Data Model Tests
    
    public static func runDataModelTests() -> Bool {
        print("\n📋 Testing Data Models...")
        var passed = true
        
        // Test 1: AppState creation
        print("Test 1: AppState model...")
        let appState = AppState(pid: 12345, name: "Slack", isActive: true)
        if appState.pid == 12345 && appState.name == "Slack" && appState.isActive {
            print("✅ AppState test passed")
        } else {
            print("❌ AppState test failed")
            passed = false
        }
        
        // Test 2: SlackMessage creation and validation
        print("Test 2: SlackMessage model...")
        let message = SlackMessage(
            timestamp: Date(),
            sender: "TestUser",
            content: "Hello, World!",
            messageType: .regular
        )
        
        do {
            try message.validate()
            if message.sender == "TestUser" && message.content == "Hello, World!" {
                print("✅ SlackMessage test passed")
            } else {
                print("❌ SlackMessage content test failed")
                passed = false
            }
        } catch {
            print("❌ SlackMessage validation failed: \(error)")
            passed = false
        }
        
        // Test 3: SlackConversation creation and validation
        print("Test 3: SlackConversation model...")
        let conversation = SlackConversation(
            workspace: "TestWorkspace",
            channel: "general",
            channelType: .publicChannel,
            messages: [message]
        )
        
        do {
            try conversation.validate()
            if conversation.workspace == "TestWorkspace" && conversation.messages.count == 1 {
                print("✅ SlackConversation test passed")
            } else {
                print("❌ SlackConversation content test failed")
                passed = false
            }
        } catch {
            print("❌ SlackConversation validation failed: \(error)")
            passed = false
        }
        
        // Test 4: Document conversion
        print("Test 4: Document conversion...")
        let document = conversation.toDocument()
        do {
            try document.validate()
            if document.source.workspace == "TestWorkspace" && document.content.contains("TestUser") {
                print("✅ Document conversion test passed")
            } else {
                print("❌ Document conversion content test failed")
                passed = false
            }
        } catch {
            print("❌ Document validation failed: \(error)")
            passed = false
        }
        
        return passed
    }
    
    // MARK: - Service Tests
    
    @MainActor
    public static func runServiceTests() async -> Bool {
        print("\n🔄 Testing Services...")
        var passed = true
        
        // Test 1: SlackMonitoringService basic functionality
        print("Test 1: SlackMonitoringService...")
        let service = SlackMonitoringService.shared
        
        // Test initial state
        if !service.isActive {
            print("✅ Initial state test passed")
        } else {
            print("❌ Initial state test failed")
            passed = false
        }
        
        // Test health check
        let healthStatus = await service.healthCheck()
        if !healthStatus.isHealthy {
            print("✅ Health check test passed (not monitoring)")
        } else {
            print("❌ Health check test failed")
            passed = false
        }
        
        // Test status info
        let status = await service.getStatusInfo()
        if !status.isMonitoring {
            print("✅ Status info test passed")
        } else {
            print("❌ Status info test failed")
            passed = false
        }
        
        return passed
    }
    
    // MARK: - Content Processing Tests
    
    public static func runContentProcessingTests() -> Bool {
        print("\n🛠 Testing Content Processing...")
        var passed = true
        
        // Test 1: Message processing
        print("Test 1: Message processing...")
        let validMessage = SlackMessage(
            timestamp: Date(),
            sender: "TestUser",
            content: "This is a valid message",
            messageType: .regular
        )
        
        if let processed = SlackContentProcessor.processMessage(validMessage) {
            print("✅ Valid message processing passed")
        } else {
            print("❌ Valid message processing failed")
            passed = false
        }
        
        // Test empty message filtering
        let emptyMessage = SlackMessage(
            timestamp: Date(),
            sender: "",
            content: "",
            messageType: .regular
        )
        
        if SlackContentProcessor.processMessage(emptyMessage) == nil {
            print("✅ Empty message filtering passed")
        } else {
            print("❌ Empty message filtering failed")
            passed = false
        }
        
        // Test 2: Content filtering
        print("Test 2: Content filtering...")
        if SlackContentFilter.shouldProcess(message: validMessage) {
            print("✅ Valid message filter passed")
        } else {
            print("❌ Valid message filter failed")
            passed = false
        }
        
        if !SlackContentFilter.shouldProcess(message: emptyMessage) {
            print("✅ Empty message filter passed")
        } else {
            print("❌ Empty message filter failed")
            passed = false
        }
        
        // Test 3: Text processing
        print("Test 3: Text processing...")
        let messyText = "  Hello    World!  \n\n  This is   messy text.  "
        let cleaned = SlackTextProcessor.cleanText(messyText)
        if cleaned == "Hello World! This is messy text." {
            print("✅ Text cleaning passed")
        } else {
            print("❌ Text cleaning failed: '\(cleaned)'")
            passed = false
        }
        
        // Test keyword extraction
        let keywords = SlackTextProcessor.extractKeywords(from: "Swift programming language development")
        if keywords.contains("swift") && keywords.contains("programming") {
            print("✅ Keyword extraction passed")
        } else {
            print("❌ Keyword extraction failed: \(keywords)")
            passed = false
        }
        
        return passed
    }
    
    // MARK: - Protocol Tests
    
    public static func runProtocolTests() -> Bool {
        print("\n🔗 Testing Protocol Conformances...")
        var passed = true
        
        // Test 1: Deduplication
        print("Test 1: Deduplication...")
        let message1 = SlackMessage(
            timestamp: Date(),
            sender: "User1",
            content: "Test message",
            messageType: .regular
        )
        
        let message2 = SlackMessage(
            timestamp: Date(),
            sender: "User1",
            content: "Test message",
            messageType: .regular
        )
        
        let key1 = message1.deduplicationKey
        let key2 = message2.deduplicationKey
        
        if key1 == key2 {
            print("✅ Deduplication key test passed")
        } else {
            print("❌ Deduplication key test failed")
            passed = false
        }
        
        // Test 2: String extensions
        print("Test 2: String extensions...")
        let testString = "Hello World"
        let hash = testString.hashValueForDeduplication
        if hash != 0 && testString.containsIgnoringCase("HELLO") {
            print("✅ String extensions test passed")
        } else {
            print("❌ String extensions test failed")
            passed = false
        }
        
        // Test 3: Date formatting
        print("Test 3: Date formatting...")
        let formatter = SlackDateReformatter()
        let testDate = formatter.parseTimestamp("2024-01-15 10:30")
        if testDate != nil {
            print("✅ Date formatting test passed")
        } else {
            print("❌ Date formatting test failed")
            passed = false
        }
        
        return passed
    }
}