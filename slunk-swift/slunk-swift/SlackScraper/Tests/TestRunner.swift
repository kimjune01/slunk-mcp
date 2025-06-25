import Foundation
import os.log

/// Detailed test runner that captures individual test results
public struct TestRunner {
    
    private static let logger = os.Logger(subsystem: "com.slunk.slunk-swift", category: "TestRunner")
    
    public static func runWithDetailedOutput() async -> String {
        let startTime = Date()
        logger.info("🧪 Starting Detailed Test Run at \(startTime)")
        
        var output: [String] = []
        
        output.append("🧪 Starting Detailed Test Run...")
        output.append("=" * 50)
        
        // Phase 1 Tests
        output.append("\n=== PHASE 1 TESTS ===")
        logger.info("=== PHASE 1 TESTS ===")
        let phase1Results = await runPhase1Tests()
        output.append(contentsOf: phase1Results)
        
        // Phase 2 Tests
        output.append("\n=== PHASE 2 TESTS ===")
        logger.info("=== PHASE 2 TESTS ===")
        let phase2Results = await runPhase2Tests()
        output.append(contentsOf: phase2Results)
        
        output.append("\n" + "=" * 50)
        output.append("🏁 Test Run Complete")
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        logger.info("🏁 Test Run Complete - Duration: \(duration)s")
        
        // Log the complete output
        let fullOutput = output.joined(separator: "\n")
        logger.info("Complete test output:\n\(fullOutput)")
        
        return fullOutput
    }
    
    private static func runPhase1Tests() async -> [String] {
        var results: [String] = []
        
        // Test 1: Data Models
        results.append("\n📋 Testing Data Models...")
        logger.info("📋 Testing Data Models...")
        do {
            let passed = SlackScraperTests.runDataModelTests()
            let result = "Data Models: \(passed ? "✅ PASS" : "❌ FAIL")"
            results.append(result)
            logger.info("\(result)")
        } catch {
            let result = "Data Models: ❌ ERROR - \(error)"
            results.append(result)
            logger.error("\(result)")
        }
        
        // Test 2: Services
        results.append("\n🔄 Testing Services...")
        logger.info("🔄 Testing Services...")
        do {
            let passed = await SlackScraperTests.runServiceTests()
            let result = "Services: \(passed ? "✅ PASS" : "❌ FAIL")"
            results.append(result)
            logger.info("\(result)")
        } catch {
            let result = "Services: ❌ ERROR - \(error)"
            results.append(result)
            logger.error("\(result)")
        }
        
        // Test 3: Content Processing
        results.append("\n🛠 Testing Content Processing...")
        logger.info("🛠 Testing Content Processing...")
        do {
            let passed = SlackScraperTests.runContentProcessingTests()
            let result = "Content Processing: \(passed ? "✅ PASS" : "❌ FAIL")"
            results.append(result)
            logger.info("\(result)")
        } catch {
            let result = "Content Processing: ❌ ERROR - \(error)"
            results.append(result)
            logger.error("\(result)")
        }
        
        // Test 4: Protocols
        results.append("\n🔗 Testing Protocols...")
        logger.info("🔗 Testing Protocols...")
        do {
            let passed = SlackScraperTests.runProtocolTests()
            let result = "Protocols: \(passed ? "✅ PASS" : "❌ FAIL")"
            results.append(result)
            logger.info("\(result)")
        } catch {
            let result = "Protocols: ❌ ERROR - \(error)"
            results.append(result)
            logger.error("\(result)")
        }
        
        return results
    }
    
    private static func runPhase2Tests() async -> [String] {
        var results: [String] = []
        
        // Test 1: DeadlineManager (skipped - using LBAccessibility framework)
        results.append("\n⏰ DeadlineManager tests skipped (using LBAccessibility framework)")
        logger.info("⏰ DeadlineManager tests skipped (using LBAccessibility framework)")
        
        // Test 2: ElementMatchers (skipped - using LBAccessibility framework)
        results.append("\n🏷️ ElementMatchers tests skipped (using LBAccessibility framework)")
        logger.info("🏷️ ElementMatchers tests skipped (using LBAccessibility framework)")
        
        // Test 3: AccessibilityCore
        results.append("\n🎯 Testing AccessibilityCore...")
        logger.info("🎯 Testing AccessibilityCore...")
        do {
            let passed = await AccessibilityCoreTests.runAllTests()
            let result = "AccessibilityCore: \(passed ? "✅ PASS" : "❌ FAIL")"
            results.append(result)
            logger.info("\(result)")
        } catch {
            let result = "AccessibilityCore: ❌ ERROR - \(error)"
            results.append(result)
            logger.error("\(result)")
        }
        
        // Test 4: SlackUIParser
        results.append("\n💬 Testing SlackUIParser...")
        logger.info("💬 Testing SlackUIParser...")
        do {
            let passed = await SlackUIParserTests.runAllTests()
            let result = "SlackUIParser: \(passed ? "✅ PASS" : "❌ FAIL")"
            results.append(result)
            logger.info("\(result)")
        } catch {
            let result = "SlackUIParser: ❌ ERROR - \(error)"
            results.append(result)
            logger.error("\(result)")
        }
        
        return results
    }
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}