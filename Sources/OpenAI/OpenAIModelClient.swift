import Foundation
import TinyAgentCore

/// OpenAI API client
public actor OpenAIModelClient: ModelClient {
    private let config: OpenAIConfig
    private let urlSession: URLSession
    
    public init(
        apiKey: String,
        baseURL: String = "https://api.openai.com/v1",
        model: String = "gpt-4",
        userAgent: String? = nil
    ) {
        self.config = OpenAIConfig(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            userAgent: userAgent
        )
        self.urlSession = URLSession(configuration: .default)
    }
    
    public func sendRequest(
        _ request: ModelRequest,
        onTranscript: (@Sendable (String) -> Void)?
    ) async throws -> ModelClientResponse {
        let url = URL(string: "\(config.baseURL)/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        // Set custom User-Agent if provided
        if let userAgent = config.userAgent {
            urlRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        
        // Build request body
        let openAIRequest = createRequest(request)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(openAIRequest)
        
        // Make request
        let (bytes, response) = try await urlSession.bytes(for: urlRequest)
        
        // Check response status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError(kind: .serverError, reason: "Invalid response type")
        }
        
        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await byte in bytes {
                errorBody.append(String(decoding: [byte], as: UTF8.self))
            }
            throw OpenAIError(
                kind: httpResponse.statusCode == 429 ? .rateLimited : .serverError,
                reason: "HTTP \(httpResponse.statusCode): \(errorBody)"
            )
        }
        
        // Parse SSE stream
        let parser = SSEParser()
        var content = ""
        var toolCalls: [ToolCallRequest] = []
        var finishReason: ModelFinishReason? = nil
        var responseId: String? = nil
        
        var partialToolCalls: [Int: ToolCall] = [:]
        
        for try await line in bytes.lines {
            let events = await parser.parse(line + "\n")
            
            for event in events {
                // Check for [DONE] marker
                if event == "[DONE]" {
                    break
                }
                
                // Parse JSON chunk
                guard let data = event.data(using: .utf8) else { continue }
                
                do {
                    let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: data)
                    
                    // Store response ID
                    if responseId == nil {
                        responseId = chunk.id
                    }
                    
                    guard let choice = chunk.choices.first else { continue }
                    
                    // Handle finish reason
                    if let reason = choice.finishReason {
                        finishReason = reason == "tool_calls" ? .toolCalls : .stop
                        break
                    }
                    
                    // Handle content delta (supports both content and reasoning_content fields)
                    if let deltaText = choice.delta.textContent {
                        content.append(deltaText)
                        onTranscript?(deltaText)
                    }
                    
                    // Handle tool calls
                    if let deltaToolCalls = choice.delta.toolCalls {
                        for toolCall in deltaToolCalls {
                            let index = toolCall.index ?? 0
                            
                            if partialToolCalls[index] == nil {
                                partialToolCalls[index] = toolCall
                            } else {
                                // Merge partial tool call
                                var existing = partialToolCalls[index]!
                                if let id = toolCall.id {
                                    existing.id = (existing.id ?? "") + id
                                }
                                if let type = toolCall.type {
                                    existing.type = (existing.type ?? "") + type
                                }
                                if let function = toolCall.function {
                                    if existing.function == nil {
                                        existing.function = function
                                    } else {
                                        if let name = function.name {
                                            existing.function!.name = (existing.function!.name ?? "") + name
                                        }
                                        if let arguments = function.arguments {
                                            existing.function!.arguments = (existing.function!.arguments ?? "") + arguments
                                        }
                                    }
                                }
                                partialToolCalls[index] = existing
                            }
                        }
                    }
                } catch {
                    // Skip invalid chunks
                    continue
                }
            }
        }
        
        // Convert partial tool calls to ToolCallRequest
        let sortedIndices = partialToolCalls.keys.sorted()
        for index in sortedIndices {
            let toolCall = partialToolCalls[index]!
            if let id = toolCall.id,
               let function = toolCall.function,
               let name = function.name {
                toolCalls.append(ToolCallRequest(
                    id: id,
                    name: name,
                    arguments: function.arguments ?? "{}"
                ))
            }
        }
        
        return ModelClientResponse(
            transcript: content,
            opaqueMessage: nil,
            toolCalls: toolCalls,
            finishReason: finishReason
        )
    }
    
    private func createRequest(_ request: ModelRequest) -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: config.model,
            messages: request.messages.map(createMessage),
            tools: request.tools.map(createTool),
            stream: true,
            streamOptions: StreamOptions(includeUsage: true)
        )
    }
    
    private func createMessage(_ msg: ModelMessage) -> Message {
        switch msg {
        case .system(let content):
            return Message(role: "system", content: content, toolCalls: nil, toolCallId: nil)
        case .user(let content):
            return Message(role: "user", content: content, toolCalls: nil, toolCallId: nil)
        case .assistant(let content):
            return Message(role: "assistant", content: content, toolCalls: nil, toolCallId: nil)
        case .tool(let result):
            return Message(role: "tool", content: result.content, toolCalls: nil, toolCallId: result.id)
        case .opaque(let opaque):
            return Message(role: "assistant", content: opaque.content, toolCalls: nil, toolCallId: nil)
        }
    }
    
    private func createTool(_ tool: ToolDefinition) -> Tool {
        Tool(
            type: "function",
            function: FunctionTool(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters
            )
        )
    }
}
