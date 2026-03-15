import Foundation

public typealias ToolResult = Result<String, ToolError>

/// Tool error
public struct ToolError: Error, Sendable {
    public enum Kind: Sendable {
        case invalidInput
        case executionFailed
        case notFound
    }

    public let kind: Kind
    public let reason: String
    
    public init(kind: Kind, reason: String) {
        self.kind = kind
        self.reason = reason
    }
}

/// Tool approval
public final class Approval: @unchecked Sendable {
    public let toolName: String
    public let justification: String
    public let what: String
    
    private var continuation: CheckedContinuation<Bool, Never>?
    
    public init(
        toolName: String,
        justification: String,
        what: String
    ) {
        self.toolName = toolName
        self.justification = justification
        self.what = what
    }
    
    public func setContinuation(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    public func approve() {
        continuation?.resume(returning: true)
    }
    
    public func reject() {
        continuation?.resume(returning: false)
    }
}

/// Tool protocol
public protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameterSchema: [String: Sendable] { get }
    
    /// Check if approval is required
    func makeApproval(input: [String: Sendable]) -> Approval?
    
    /// Execute the tool
    func execute(input: [String: Sendable]) async -> ToolResult
}

/// Tool manager
public actor ToolManager {
    private var tools: [String: any Tool] = [:]
    
    public init() {}
    
    public func register(_ tool: some Tool) {
        tools[tool.name] = tool
    }
    
    public func getDefinition(name: String) -> ToolDefinition? {
        guard let tool = tools[name] else { return nil }
        return ToolDefinition(
            name: tool.name,
            description: tool.description,
            parameters: tool.parameterSchema
        )
    }
    
    public func definitions() -> [ToolDefinition] {
        tools.values.map { tool in
            ToolDefinition(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameterSchema
            )
        }
    }
    
    public func handleRequest(
        _ request: ToolCallRequest,
        onApprovalRequest: (@Sendable (Approval) async -> Bool)? = nil
    ) async -> ToolResult {
        guard let tool = tools[request.name] else {
            return .failure(ToolError(kind: .notFound, reason: "Tool '\(request.name)' not found"))
        }

        // Parse arguments
        guard let data = request.arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Sendable] else {
            return .failure(ToolError(kind: .invalidInput, reason: "Invalid JSON arguments"))
        }

        // Check if approval is required
        if let approval = tool.makeApproval(input: json) {
            guard let onApprovalRequest = onApprovalRequest else {
                return .failure(ToolError(kind: .executionFailed, reason: "Tool '\(tool.name)' requires approval but no approval handler provided"))
            }

            // Wait for user approval
            let approved = await onApprovalRequest(approval)

            guard approved else {
                return .failure(ToolError(kind: .executionFailed, reason: "User rejected tool '\(tool.name)' execution"))
            }
        }

        return await tool.execute(input: json)
    }
}
