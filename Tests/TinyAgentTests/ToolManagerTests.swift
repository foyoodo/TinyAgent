import Testing
import Foundation
import TinyAgentCore
@testable import TinyAgent

// MARK: - Test Tags

extension Tag {
    @Tag static var toolManager: Self
}

// MARK: - Mock Tool for Testing

struct MockTool: Tool {
    let name: String
    let description: String
    let parameterSchema: [String: Sendable]
    let shouldRequireApproval: Bool
    let executionResult: ToolResult
    
    func makeApproval(input: [String: Sendable]) -> Approval? {
        guard shouldRequireApproval else { return nil }
        return Approval(
            toolName: name,
            justification: "Test approval required",
            what: "Test operation"
        )
    }
    
    func execute(input: [String: Sendable]) async -> ToolResult {
        executionResult
    }
}

// MARK: - ToolManager Tests

@Suite("ToolManager Tests", .tags(.toolManager))
struct ToolManagerTests {
    
    // MARK: - Registration Tests
    
    @Test("Can register and retrieve tool")
    func registerAndRetrieveTool() async throws {
        let manager = ToolManager()
        let tool = MockTool(
            name: "test-tool",
            description: "A test tool",
            parameterSchema: [:],
            shouldRequireApproval: false,
            executionResult: .success("result")
        )
        
        await manager.register(tool)
        
        let definition = await manager.getDefinition(name: "test-tool")
        let unwrappedDefinition = try #require(definition, "Should retrieve registered tool definition")
        #expect(unwrappedDefinition.name == "test-tool")
        #expect(unwrappedDefinition.description == "A test tool")
    }
    
    @Test("Returns nil for unregistered tool")
    func returnsNilForUnregisteredTool() async {
        let manager = ToolManager()
        
        let definition = await manager.getDefinition(name: "non-existent")
        
        #expect(definition == nil, "Should return nil for unregistered tool")
    }
    
    @Test("Can register multiple tools")
    func registerMultipleTools() async {
        let manager = ToolManager()
        
        let tools = [
            MockTool(name: "tool-1", description: "First tool", parameterSchema: [:], shouldRequireApproval: false, executionResult: .success("1")),
            MockTool(name: "tool-2", description: "Second tool", parameterSchema: [:], shouldRequireApproval: false, executionResult: .success("2")),
            MockTool(name: "tool-3", description: "Third tool", parameterSchema: [:], shouldRequireApproval: false, executionResult: .success("3")),
        ]
        
        for tool in tools {
            await manager.register(tool)
        }
        
        let definitions = await manager.definitions()
        
        #expect(definitions.count == 3, "Should have 3 registered tools")
        
        let names = Set(definitions.map { $0.name })
        #expect(names == Set(["tool-1", "tool-2", "tool-3"]), "Should have all registered tool names")
    }
    
    @Test("Registering tool with same name replaces previous")
    func registerReplacesPrevious() async {
        let manager = ToolManager()
        
        let firstTool = MockTool(name: "same-name", description: "First", parameterSchema: [:], shouldRequireApproval: false, executionResult: .success("first"))
        let secondTool = MockTool(name: "same-name", description: "Second", parameterSchema: [:], shouldRequireApproval: false, executionResult: .success("second"))
        
        await manager.register(firstTool)
        await manager.register(secondTool)
        
        let definitions = await manager.definitions()
        #expect(definitions.count == 1, "Should only have one tool")
        #expect(definitions.first?.description == "Second", "Should have the second tool's description")
    }
    
    // MARK: - Tool Execution Tests
    
    @Test("Execute registered tool successfully")
    func executeRegisteredTool() async {
        let manager = ToolManager()
        let tool = MockTool(
            name: "success-tool",
            description: "Always succeeds",
            parameterSchema: ["param": "string"],
            shouldRequireApproval: false,
            executionResult: .success("success result")
        )
        
        await manager.register(tool)
        
        let request = ToolCallRequest(
            id: "call-1",
            name: "success-tool",
            arguments: "{\"param\": \"value\"}"
        )
        
        let result = await manager.handleRequest(request)
        
        #expect(result.isSuccess, "Should successfully execute tool")
        if case .success(let output) = result {
            #expect(output == "success result")
        }
    }
    
    @Test("Execute returns error for unregistered tool")
    func executeUnregisteredTool() async {
        let manager = ToolManager()
        
        let request = ToolCallRequest(
            id: "call-1",
            name: "unknown-tool",
            arguments: "{}"
        )
        
        let result = await manager.handleRequest(request)
        
        #expect(result.isFailure, "Should fail for unregistered tool")
        #expect(result.errorKind == .notFound, "Error should be notFound")
    }
    
    @Test("Execute returns error for invalid JSON arguments")
    func executeInvalidJSON() async {
        let manager = ToolManager()
        let tool = MockTool(
            name: "json-tool",
            description: "Tests JSON parsing",
            parameterSchema: [:],
            shouldRequireApproval: false,
            executionResult: .success("result")
        )
        
        await manager.register(tool)
        
        let request = ToolCallRequest(
            id: "call-1",
            name: "json-tool",
            arguments: "not valid json"
        )
        
        let result = await manager.handleRequest(request)
        
        #expect(result.isFailure, "Should fail with invalid JSON")
        #expect(result.errorKind == .invalidInput, "Error should be invalidInput")
    }
    
    @Test("Execute with approval approval approved")
    func executeWithApprovalApproved() async {
        let manager = ToolManager()
        let tool = MockTool(
            name: "approval-tool",
            description: "Requires approval",
            parameterSchema: [:],
            shouldRequireApproval: true,
            executionResult: .success("approved result")
        )
        
        await manager.register(tool)
        
        let request = ToolCallRequest(
            id: "call-1",
            name: "approval-tool",
            arguments: "{}"
        )
        
        let result = await manager.handleRequest(request) { approval in
            // Approve the request
            return true
        }
        
        #expect(result.isSuccess, "Should execute when approved")
    }
    
    @Test("Execute with approval rejected")
    func executeWithApprovalRejected() async {
        let manager = ToolManager()
        let tool = MockTool(
            name: "approval-tool",
            description: "Requires approval",
            parameterSchema: [:],
            shouldRequireApproval: true,
            executionResult: .success("should not reach here")
        )
        
        await manager.register(tool)
        
        let request = ToolCallRequest(
            id: "call-1",
            name: "approval-tool",
            arguments: "{}"
        )
        
        let result = await manager.handleRequest(request) { approval in
            // Reject the request
            return false
        }
        
        #expect(result.isFailure, "Should fail when rejected")
        #expect(result.errorKind == .executionFailed, "Error should be executionFailed")
    }
    
    @Test("Execute with approval but no handler")
    func executeWithApprovalNoHandler() async {
        let manager = ToolManager()
        let tool = MockTool(
            name: "approval-tool",
            description: "Requires approval",
            parameterSchema: [:],
            shouldRequireApproval: true,
            executionResult: .success("result")
        )
        
        await manager.register(tool)
        
        let request = ToolCallRequest(
            id: "call-1",
            name: "approval-tool",
            arguments: "{}"
        )
        
        // No approval handler provided
        let result = await manager.handleRequest(request, onApprovalRequest: nil)
        
        #expect(result.isFailure, "Should fail when approval required but no handler")
        #expect(result.errorKind == .executionFailed, "Error should be executionFailed")
    }
    
    // MARK: - Tool Definition Tests
    
    @Test("Definitions returns all registered tools")
    func definitionsReturnsAllTools() async {
        let manager = ToolManager()
        
        await manager.register(ShellTool())
        await manager.register(GlobTool())
        await manager.register(ReadFileTool())
        
        let definitions = await manager.definitions()
        
        #expect(definitions.count == 3, "Should return all 3 built-in tools")
        
        let names = definitions.map { $0.name }.sorted()
        #expect(names == ["glob", "read_file", "shell"], "Should have correct tool names")
    }
    
    @Test("Empty manager returns empty definitions")
    func emptyManagerReturnsEmptyDefinitions() async {
        let manager = ToolManager()
        
        let definitions = await manager.definitions()
        
        #expect(definitions.isEmpty, "Empty manager should return empty definitions")
    }
}


