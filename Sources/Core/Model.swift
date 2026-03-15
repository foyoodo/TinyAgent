import Foundation

/// Model provider error protocol
public protocol ModelProviderError: Error, Sendable {
    var errorKind: ErrorKind { get }
}

/// Error kinds
public enum ErrorKind: Sendable {
    case rateLimited
    case invalidRequest
    case serverError
    case networkError
    case unknown
}

/// Model message types
public enum ModelMessage: Sendable {
    case system(String)
    case user(String)
    case assistant(String)
    case tool(ToolCallResult)
    case opaque(OpaqueMessage)
}

/// Opaque message for specific model implementations
public struct OpaqueMessage: Sendable {
    public let content: String
    
    public init(content: String) {
        self.content = content
    }
}

/// Tool call request
public struct ToolCallRequest: Sendable {
    public let id: String
    public let name: String
    public let arguments: String
    
    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// Tool call result
public struct ToolCallResult: Sendable {
    public let id: String
    public let content: String
    
    public init(id: String, content: String) {
        self.id = id
        self.content = content
    }
}

/// Model finish reason
public enum ModelFinishReason: Sendable {
    case stop
    case toolCalls
    case length
    case contentFilter
    case unknown
}

/// Model request
public struct ModelRequest: Sendable {
    public var messages: [ModelMessage]
    public var tools: [ToolDefinition]
    
    public init(messages: [ModelMessage] = [], tools: [ToolDefinition] = []) {
        self.messages = messages
        self.tools = tools
    }
}

/// Tool definition
public struct ToolDefinition: Sendable {
    public let name: String
    public let description: String
    public let parameters: [String: Sendable]
    
    public init(name: String, description: String, parameters: [String: Sendable]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Model response protocol
public protocol ModelResponse: Sendable {
    associatedtype Error: ModelProviderError
    
    var transcript: String { get }
    var opaqueMessage: OpaqueMessage? { get }
    var toolCalls: [ToolCallRequest] { get }
    var finishReason: ModelFinishReason? { get }
}

/// Model provider protocol
public protocol ModelProvider: Sendable {
    associatedtype Response: ModelResponse
    
    func sendRequest(
        _ request: ModelRequest
    ) async throws -> Response
}
