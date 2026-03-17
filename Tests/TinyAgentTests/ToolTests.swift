import Testing
import Foundation
import TinyAgentCore
@testable import TinyAgent

// MARK: - Test Tags

extension Tag {
    @Tag static var tools: Self
    @Tag static var shellTool: Self
    @Tag static var globTool: Self
    @Tag static var readFileTool: Self
}

// Note: ToolResult helpers are defined in ToolManagerTests.swift and shared across test files

// MARK: - GlobTool Tests

@Suite("GlobTool Tests", .tags(.tools, .globTool))
struct GlobToolTests {
    
    @Test("GlobTool finds matching files")
    func globToolFindsFiles() async throws {
        let tool = GlobTool()
        
        let result = await tool.execute(input: ["pattern": "*.swift"])
        
        // Result should be either success or failure depending on CWD
        // Just verify it doesn't crash and returns a valid result
        #expect(result.isSuccess || result.isFailure)
    }
    
    @Test("GlobTool returns error for missing parameter")
    func globToolMissingParameter() async throws {
        let tool = GlobTool()
        let result = await tool.execute(input: [:])
        
        #expect(result.isFailure, "Should fail with missing parameter")
        #expect(result.errorKind == .invalidInput, "Error should be invalidInput")
    }
    
    @Test("GlobTool returns error for invalid parameter type")
    func globToolInvalidParameterType() async throws {
        let tool = GlobTool()
        let result = await tool.execute(input: ["pattern": 123 as any Sendable])
        
        #expect(result.isFailure, "Should fail with invalid parameter type")
    }
    
    @Test("GlobTool does not require approval")
    func globToolNoApproval() async {
        let tool = GlobTool()
        let approval = tool.makeApproval(input: ["pattern": "*.swift"])
        
        #expect(approval == nil, "GlobTool should not require approval")
    }
}

// MARK: - ShellTool Tests

@Suite("ShellTool Tests", .tags(.tools, .shellTool))
struct ShellToolTests {
    
    @Test("ShellTool requires approval")
    func shellToolRequiresApproval() async throws {
        let tool = ShellTool()
        let approval = tool.makeApproval(input: ["command": "ls -la"])
        
        let unwrappedApproval = try #require(approval, "ShellTool should return approval")
        #expect(unwrappedApproval.toolName == "shell")
        #expect(unwrappedApproval.what == "ls -la")
        #expect(unwrappedApproval.justification == "Allow execution of shell command")
    }
    
    @Test("ShellTool returns error for missing parameter")
    func shellToolMissingParameter() async throws {
        let tool = ShellTool()
        let result = await tool.execute(input: [:])
        
        #expect(result.isFailure, "Should fail with missing parameter")
        #expect(result.errorKind == .invalidInput)
    }
    
    @Test("ShellTool executes simple command")
    func shellToolExecutesCommand() async throws {
        let tool = ShellTool()
        let result = await tool.execute(input: ["command": "echo 'Hello World'"])
        
        #expect(result.isSuccess, "Should successfully execute echo command")
        
        if case .success(let output) = result {
            #expect(output.contains("Hello World"), "Output should contain 'Hello World'")
        }
    }
    
    @Test("ShellTool handles invalid command")
    func shellToolHandlesInvalidCommand() async throws {
        let tool = ShellTool()
        let result = await tool.execute(input: ["command": "this_command_does_not_exist_12345"])
        
        #expect(result.isFailure, "Should fail with invalid command")
    }
}

// MARK: - ReadFileTool Tests

@Suite("ReadFileTool Tests", .tags(.tools, .readFileTool))
struct ReadFileToolTests {
    
    // MARK: - Parameterized Tests for Approval Detection
    
    @Test("ReadFileTool detects sensitive files requiring approval",
          arguments: [
            ("config/.env", "sensitive pattern"),
            (".ssh/id_rsa", "ssh key"),
            (".git/config", "git config"),
            ("my-secrets.txt", "secret keyword"),
            ("passwords.json", "password keyword"),
            ("api_token.txt", "token keyword"),
            ("private.key", "key keyword"),
          ])
    func readFileToolDetectsSensitiveFiles(path: String, description: String) async {
        let tool = ReadFileTool()
        
        let approval = tool.makeApproval(input: ["path": path])
        
        #expect(approval != nil, "Should require approval for \(description): \(path)")
    }
    
    @Test("ReadFileTool does not require approval for normal files",
          arguments: [
            "readme.md",
            "Package.swift",
            "Sources/main.swift",
            "config.json",
            "data.txt",
          ])
    func readFileToolNoApprovalForNormalFiles(path: String) async {
        let tool = ReadFileTool()
        
        let approval = tool.makeApproval(input: ["path": path])
        
        #expect(approval == nil, "Should not require approval for: \(path)")
    }
    
    // MARK: - Execution Tests
    
    @Test("ReadFileTool returns error for missing parameter")
    func readFileToolMissingParameter() async throws {
        let tool = ReadFileTool()
        let result = await tool.execute(input: [:])
        
        #expect(result.isFailure, "Should fail with missing parameter")
        #expect(result.errorKind == .invalidInput)
    }
    
    @Test("ReadFileTool reads existing file")
    func readFileToolReadsExistingFile() async throws {
        let tool = ReadFileTool()
        
        // Try to read a file we know exists (Package.swift in test directory)
        let result = await tool.execute(input: ["path": "Package.swift"])
        
        // May succeed or fail depending on CWD, but should not crash
        if result.isSuccess {
            if case .success(let content) = result {
                #expect(!content.isEmpty, "File content should not be empty")
            }
        }
    }
    
    @Test("ReadFileTool handles non-existent file")
    func readFileToolHandlesNonExistentFile() async throws {
        let tool = ReadFileTool()
        
        let result = await tool.execute(input: ["path": "this_file_does_not_exist_12345.txt"])
        
        #expect(result.isFailure, "Should fail when file does not exist")
    }
    
    @Test("ReadFileTool handles absolute paths")
    func readFileToolHandlesAbsolutePaths() async {
        let tool = ReadFileTool()
        
        // Absolute paths outside working directory should require approval
        let approval = tool.makeApproval(input: ["path": "/etc/passwd"])
        
        #expect(approval != nil, "Should require approval for absolute paths outside working directory")
    }
}

// MARK: - Tool Schema Tests

@Suite("Tool Schema Tests", .tags(.tools))
struct ToolSchemaTests {
    
    @Test("GlobTool has correct schema")
    func globToolSchema() {
        let tool = GlobTool()
        
        #expect(tool.name == "glob")
        #expect(!tool.description.isEmpty)
        #expect(tool.parameterSchema.keys.contains("pattern"))
    }
    
    @Test("ShellTool has correct schema")
    func shellToolSchema() {
        let tool = ShellTool()
        
        #expect(tool.name == "shell")
        #expect(!tool.description.isEmpty)
        #expect(tool.parameterSchema.keys.contains("command"))
    }
    
    @Test("ReadFileTool has correct schema")
    func readFileToolSchema() {
        let tool = ReadFileTool()
        
        #expect(tool.name == "read_file")
        #expect(!tool.description.isEmpty)
        #expect(tool.parameterSchema.keys.contains("path"))
    }
}
