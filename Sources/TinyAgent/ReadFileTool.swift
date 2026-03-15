import Foundation
import TinyAgentCore

/// Read file tool
public struct ReadFileTool: Tool {
    public var name: String { "read_file" }
    
    public var description: String {
        "Read contents of a file"
    }
    
    public var parameterSchema: [String : Sendable] {
        [
            "path": "string"
        ]
    }
    
    public func makeApproval(input: [String : Sendable]) -> Approval? {
        guard let path = input["path"] as? String else {
            return nil
        }
        
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let fullPath = path.hasPrefix("/") ? path : "\(currentDir)/\(path)"
        
        // If file is outside current working directory, approval is needed
        let isOutsideWorkingDir = !fullPath.hasPrefix(currentDir)
        
        // Check if file is sensitive
        let sensitivePatterns = [".env", ".ssh", ".git/config", ".cursor/", "secret", "password", "token", "key"]
        let isSensitiveFile = sensitivePatterns.contains { pattern in
            fullPath.lowercased().contains(pattern.lowercased())
        }
        
        if isOutsideWorkingDir || isSensitiveFile {
            let reason = isOutsideWorkingDir
                ? "Reading file outside working directory"
                : "Reading potentially sensitive file"
            
            return Approval(
                toolName: name,
                justification: reason,
                what: fullPath
            )
        }
        
        return nil
    }
    
    public func execute(input: [String : Sendable]) async -> ToolResult {
        guard let path = input["path"] as? String else {
            return .failure(ToolError(kind: .invalidInput, reason: "Missing 'path' parameter"))
        }
        
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let fullPath = path.hasPrefix("/") ? path : "\(currentDir)/\(path)"
        
        do {
            let content = try String(contentsOfFile: fullPath, encoding: .utf8)
            return .success(content)
        } catch {
            return .failure(ToolError(kind: .executionFailed, reason: error.localizedDescription))
        }
    }
}
