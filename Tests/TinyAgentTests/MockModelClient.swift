import Foundation
import TinyAgentCore

/// Mock model provider for testing
public actor MockModelClient: ModelClient {
    private let responses: [String]
    private var index = 0
    
    public init(responses: [String] = ["Hello!", "How can I help you?"]) {
        self.responses = responses
    }
    
    public func sendRequest(
        _ request: ModelRequest,
        onTranscript: (@Sendable (String) -> Void)?
    ) async throws -> ModelClientResponse {
        let response = responses[index % responses.count]
        index += 1
        
        // Simulate streaming response
        onTranscript?(response)
        
        return ModelClientResponse(
            transcript: response,
            opaqueMessage: nil,
            toolCalls: [],
            finishReason: .stop
        )
    }
}

/// Test model response
public struct TestModelResponse: ModelResponse {
    public typealias Error = TestModelError
    
    public let transcript: String
    public let opaqueMessage: OpaqueMessage?
    public let toolCalls: [ToolCallRequest]
    public let finishReason: ModelFinishReason?
}

/// Test model error
public struct TestModelError: ModelProviderError {
    public let errorKind: ErrorKind
    public let reason: String
    
    public init(kind: ErrorKind, reason: String) {
        self.errorKind = kind
        self.reason = reason
    }
}
