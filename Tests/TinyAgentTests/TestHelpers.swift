import Testing
import Foundation
import TinyAgentCore

// MARK: - ToolResult Test Helpers

extension ToolResult {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
    
    var errorKind: ToolError.Kind? {
        if case .failure(let error) = self { return error.kind }
        return nil
    }
}
