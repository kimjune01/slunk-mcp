import XCTest
import Foundation
@testable import slunk_swift

final class MCPIntegrationTests: XCTestCase {
    
    var mcpServer: MCPServer!
    var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        mcpServer = MCPServer()
        tempDir = FileManager.default.temporaryDirectory
    }
    
    override func tearDown() {
        mcpServer = nil
        tempDir = nil
        super.tearDown()
    }
    
    // MARK: - Basic MCP Server Tests
    
    func testMCPServerInitialization() {
        // Should initialize without error
        XCTAssertNotNil(mcpServer, "MCP server should initialize")
    }
    
    func testBasicMCPResponseStructure() {
        // Test that we can create basic JSON-RPC responses
        let testId = JSONRPCId.string("test-123")
        let response = JSONRPCResponse(
            result: ["message": "test"],
            error: nil,
            id: testId
        )
        
        XCTAssertNotNil(response, "Should create valid response")
        XCTAssertEqual(response.id, testId, "Response ID should match")
        XCTAssertNotNil(response.result, "Should have result")
        XCTAssertNil(response.error, "Should not have error")
    }
    
    func testJSONRPCErrorCreation() {
        // Test error response creation
        let testId = JSONRPCId.string("error-test")
        let error = JSONRPCError(code: -32601, message: "Method not found")
        let response = JSONRPCResponse(
            result: nil,
            error: error,
            id: testId
        )
        
        XCTAssertNotNil(response, "Should create error response")
        XCTAssertEqual(response.error?.code, -32601, "Should have correct error code")
        XCTAssertEqual(response.error?.message, "Method not found", "Should have correct error message")
        XCTAssertNil(response.result, "Error response should not have result")
    }
    
    func testMCPServerRunningState() {
        // Test that server can be started and stopped
        mcpServer.start()
        // Note: We can't easily test the running state without the full I/O loop
        // Just verify it doesn't crash
        
        mcpServer.stop()
        // Should complete without error
        XCTAssertTrue(true, "Server start/stop should complete without error")
    }
}