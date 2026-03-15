import Foundation
import TinyAgentCore

/// Shell tool
public struct ShellTool: Tool {
    public var name: String { "shell" }
    
    public var description: String {
        "Execute shell commands"
    }
    
    public var parameterSchema: [String : Sendable] {
        [
            "command": "string"
        ]
    }
    
    public func makeApproval(input: [String : Sendable]) -> Approval? {
        guard let command = input["command"] as? String else {
            return nil
        }
        
        return Approval(
            toolName: name,
            justification: "Allow execution of shell command",
            what: command
        )
    }
    
    public func execute(input: [String : Sendable]) async -> ToolResult {
        guard let command = input["command"] as? String else {
            return .failure(ToolError(kind: .invalidInput, reason: "Missing 'command' parameter"))
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                return .success(output)
            } else {
                return .failure(ToolError(kind: .executionFailed, reason: output))
            }
        } catch {
            return .failure(ToolError(kind: .executionFailed, reason: error.localizedDescription))
        }
    }
}
