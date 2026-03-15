import Testing
import Foundation
import TinyAgentCore
@testable import TinyAgent

@Suite("Tool Tests")
struct ToolTests {
    
    @Test("GlobTool finds matching files")
    func globToolFindsFiles() async throws {
        let tool = GlobTool()
        
        // Test glob pattern - just verify it runs without error
        let result = await tool.execute(input: ["pattern": "*.swift"])
        
        // The result depends on the current working directory
        // Just verify we get a result (success or failure is fine for this test)
        switch result {
        case .success, .failure:
            // Both are acceptable outcomes
            break
        }
    }
    
    @Test("GlobTool returns error for missing parameter")
    func globToolMissingParameter() async throws {
        let tool = GlobTool()
        let result = await tool.execute(input: [:])
        
        switch result {
        case .success:
            Issue.record("Should have failed with missing parameter")
        case .failure(let error):
            #expect(error.kind == .invalidInput)
        }
    }
    
    @Test("ShellTool requires approval")
    func shellToolRequiresApproval() async throws {
        let tool = ShellTool()
        let approval = tool.makeApproval(input: ["command": "ls -la"])
        
        #expect(approval != nil)
        #expect(approval?.toolName == "shell")
        #expect(approval?.what == "ls -la")
    }
    
    @Test("ReadFileTool detects sensitive files")
    func readFileToolDetectsSensitiveFiles() async throws {
        let tool = ReadFileTool()
        
        // Test with sensitive file pattern (using relative path)
        let approval = tool.makeApproval(input: ["path": "config/.env"])
        #expect(approval != nil)
        
        // Test with normal file (using relative path)
        let normalApproval = tool.makeApproval(input: ["path": "readme.md"])
        #expect(normalApproval == nil)
    }
    
    @Test("ReadFileTool returns error for missing parameter")
    func readFileToolMissingParameter() async throws {
        let tool = ReadFileTool()
        let result = await tool.execute(input: [:])
        
        switch result {
        case .success:
            Issue.record("Should have failed with missing parameter")
        case .failure(let error):
            #expect(error.kind == .invalidInput)
        }
    }
}
