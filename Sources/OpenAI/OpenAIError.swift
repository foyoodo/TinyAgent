import Foundation
import TinyAgentCore

/// OpenAI error type
public struct OpenAIError: Error, ModelProviderError, Sendable {
    public let errorKind: ErrorKind
    public let reason: String
    
    public init(kind: ErrorKind, reason: String) {
        self.errorKind = kind
        self.reason = reason
    }
}
