import Foundation

// MARK: - Request Types

struct ChatCompletionRequest: Encodable {
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

struct StreamOptions: Encodable {
    let includeUsage: Bool
    
    enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
    }
}

struct Message: Encodable {
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

struct Tool: Encodable {
    let type: String
    let function: FunctionTool
}

struct FunctionTool: Encodable {
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

struct ToolCall: Codable {
    var id: String?
    var type: String?
    let index: Int?
    var function: FunctionToolCall?
}

struct FunctionToolCall: Codable {
    var name: String?
    var arguments: String?
}

// MARK: - Response Types

struct ChatCompletionChunk: Codable {
    let id: String
    let choices: [Choice]
}

struct Choice: Codable {
    let delta: Delta
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

struct Delta: Codable {
    let content: String?
    let toolCalls: [ToolCall]?
    
    enum CodingKeys: String, CodingKey {
        case content
        case toolCalls = "tool_calls"
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
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
