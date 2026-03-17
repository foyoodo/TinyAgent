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
        
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: .success(output))
                } else {
                    continuation.resume(returning: .failure(ToolError(kind: .executionFailed, reason: output)))
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: .failure(ToolError(kind: .executionFailed, reason: error.localizedDescription)))
            }
        }
    }
}
