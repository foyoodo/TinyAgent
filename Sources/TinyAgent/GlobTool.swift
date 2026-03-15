import Foundation
import TinyAgentCore

/// Glob tool
public struct GlobTool: Tool {
    public var name: String { "glob" }
    
    public var description: String {
        "Find files matching a pattern"
    }
    
    public var parameterSchema: [String : Sendable] {
        [
            "pattern": "string"
        ]
    }
    
    public func makeApproval(input: [String : Sendable]) -> Approval? {
        // Glob tool is relatively safe, no approval needed
        return nil
    }
    
    public func execute(input: [String : Sendable]) async -> ToolResult {
        guard let pattern = input["pattern"] as? String else {
            return .failure(ToolError(kind: .invalidInput, reason: "Missing 'pattern' parameter"))
        }
        
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: currentDir)
            let matching = contents.filter { path in
                path.matches(glob: pattern)
            }
            
            return .success(matching.joined(separator: "\n"))
        } catch {
            return .failure(ToolError(kind: .executionFailed, reason: error.localizedDescription))
        }
    }
}

extension String {
    func matches(glob pattern: String) -> Bool {
        // Simplified glob matching
        if pattern == "*" { return true }
        if pattern.hasPrefix("*") {
            let suffix = String(pattern.dropFirst())
            return self.hasSuffix(suffix)
        }
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return self.hasPrefix(prefix)
        }
        return self == pattern
    }
}
