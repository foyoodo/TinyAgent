import Foundation

// MARK: - Request Types

struct ChatCompletionRequest: Encodable, Sendable {
    let model: String
    let messages: [Message]
    let tools: [Tool]
    let stream: Bool
    let streamOptions: StreamOptions?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case tools
        case stream
        case streamOptions = "stream_options"
    }
}

struct StreamOptions: Encodable, Sendable {
    let includeUsage: Bool
    
    enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
    }
}

struct Message: Encodable, Sendable {
    let role: String
    let content: String?
    let toolCalls: [ToolCall]?
    let toolCallId: String?
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

struct Tool: Encodable, Sendable {
    let type: String
    let function: FunctionTool
}

struct FunctionTool: Encodable, Sendable {
    let name: String
    let description: String
    let parameters: [String: Sendable]
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case parameters
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        
        // Convert Sendable dictionary to JSON-compatible dictionary
        var jsonParams: [String: AnyCodable] = [:]
        for (key, value) in parameters {
            jsonParams[key] = AnyCodable(value)
        }
        try container.encode(jsonParams, forKey: .parameters)
    }
}

/// Tool call in a delta
public struct ToolCall: Codable, Sendable {
    public var id: String?
    public var type: String?
    public let index: Int?
    public var function: FunctionToolCall?
}

/// Function tool call details
public struct FunctionToolCall: Codable, Sendable {
    public var name: String?
    public var arguments: String?
}

// MARK: - Response Types

/// Chat completion chunk from streaming response
public struct ChatCompletionChunk: Codable, Sendable {
    public let id: String
    public let choices: [Choice]
}

/// Choice within a chat completion chunk
public struct Choice: Codable, Sendable {
    public let delta: Delta
    public let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

/// Delta content in a streaming chunk
public struct Delta: Codable, Sendable {
    public let role: String?
    public let content: String?
    public let reasoningContent: String?
    public let toolCalls: [ToolCall]?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case reasoningContent = "reasoning_content"
        case toolCalls = "tool_calls"
    }

    /// Returns the actual text content from either content or reasoning_content field
    public var textContent: String? {
        content ?? reasoningContent
    }
}

// MARK: - AnyCodable Helper

/// AnyCodable is used internally for encoding JSON parameters.
///
/// **Concurrency Safety**: Marked as `@unchecked Sendable` because all values come from
/// `ToolDefinition.parameters` which is `[String: Sendable]`. The caller ensures Sendable
/// safety by construction - all values are controlled by the framework, not user input.
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }
}
