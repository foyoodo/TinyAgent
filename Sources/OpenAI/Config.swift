import Foundation

/// OpenAI configuration
public struct OpenAIConfig: Sendable {
    public let apiKey: String
    public let model: String
    public let baseURL: String
    
    public init(
        apiKey: String,
        model: String = "gpt-4",
        baseURL: String = "https://api.openai.com/v1"
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
    }
}
