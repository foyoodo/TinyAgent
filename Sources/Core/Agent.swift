import Foundation

/// Agent event types
public enum AgentEvent: Sendable {
    /// Agent enters idle state
    case idle
    /// Transcript delta (streaming chunk)
    case transcriptDelta(TranscriptDelta)
    /// Error occurred
    case error(any ModelProviderError)
    /// Tool call request requiring user approval
    case toolCallRequest(Approval)
    /// Tool call completed
    case toolCallCompleted(String, ToolResult)
}

/// Agent stages
public enum AgentStage: Sendable {
    case idle
    case modelThinking
    case runningTools
}

/// Transcript source
public enum TranscriptSource: Sendable, Equatable {
    case user
    case assistant(isReasoning: Bool)

    public var isAssistant: Bool {
        if case .assistant = self { return true }
        return false
    }

    public var isReasoning: Bool {
        if case .assistant(let reasoning) = self { return reasoning }
        return false
    }

    public static func == (lhs: TranscriptSource, rhs: TranscriptSource) -> Bool {
        switch (lhs, rhs) {
        case (.user, .user):
            return true
        case (.assistant(let lhsReasoning), .assistant(let rhsReasoning)):
            return lhsReasoning == rhsReasoning
        default:
            return false
        }
    }
}

/// Represents a delta (incremental update) of a transcript
public struct TranscriptDelta: Sendable {
    /// The new content chunk to append
    public let content: String
    /// Whether this is the final chunk of the transcript
    public let isComplete: Bool
    /// The source of the transcript (user, assistant, or assistantReasoning)
    public let source: TranscriptSource

    public init(content: String, isComplete: Bool, source: TranscriptSource) {
        self.content = content
        self.isComplete = isComplete
        self.source = source
    }
}

/// Model client protocol
public protocol ModelClient: Sendable {
    /// Send a request to the model
    /// - Parameters:
    ///   - request: The model request
    ///   - onTranscript: Callback for streaming transcript updates. Parameters:
    ///     - String: The content chunk
    ///     - Bool: Whether this is reasoning content
    ///     - Bool: Whether this is the start of a new message (has role field)
    func sendRequest(
        _ request: ModelRequest,
        onTranscript: (@Sendable (String, Bool, Bool) -> Void)?
    ) async throws -> ModelClientResponse
}

/// Model client response
public struct ModelClientResponse: Sendable {
    public let transcript: String
    public let opaqueMessage: OpaqueMessage?
    public let toolCalls: [ToolCallRequest]
    public let finishReason: ModelFinishReason?
    
    public init(
        transcript: String,
        opaqueMessage: OpaqueMessage? = nil,
        toolCalls: [ToolCallRequest] = [],
        finishReason: ModelFinishReason? = nil
    ) {
        self.transcript = transcript
        self.opaqueMessage = opaqueMessage
        self.toolCalls = toolCalls
        self.finishReason = finishReason
    }
}

/// Agent Actor using Swift Actor for state isolation
public actor Agent {
    // Dependencies
    private var modelClient: ModelClient
    private let toolManager: ToolManager
    private var conversation: Conversation
    
    // State
    private var currentStage: AgentStage
    private var pendingInputs: [String]
    private var pendingToolCalls: [String]
    private var completedToolResults: [String: ToolResult]
    
    // AsyncStream
    private let eventStream: AsyncStream<AgentEvent>
    private let eventContinuation: AsyncStream<AgentEvent>.Continuation
    
    public init(
        modelClient: ModelClient,
        toolManager: ToolManager,
        systemPrompt: String? = nil
    ) {
        self.modelClient = modelClient
        self.toolManager = toolManager
        self.conversation = Conversation()
        self.currentStage = .idle
        self.pendingInputs = []
        self.pendingToolCalls = []
        self.completedToolResults = [:]

        // Create event stream using modern factory method
        let (stream, continuation) = AsyncStream.makeStream(of: AgentEvent.self)
        self.eventStream = stream
        self.eventContinuation = continuation

        // Add system prompt
        if let prompt = systemPrompt {
            self.conversation.append(Conversation.Item(
                message: .system(prompt),
                transcript: prompt
            ))
        }
    }
    
    /// Event stream for external consumption via for await
    public var events: AsyncStream<AgentEvent> {
        eventStream
    }
    
    /// Queue user input
    public func enqueueUserInput(_ input: String) async {
        // If not in idle state, queue for later
        guard currentStage == .idle else {
            pendingInputs.append(input)
            return
        }

        await processInput(input)
    }

    private func processInput(_ input: String) async {
        // Yield user transcript as a complete delta (no streaming for user input)
        let delta = TranscriptDelta(content: input, isComplete: true, source: .user)
        eventContinuation.yield(.transcriptDelta(delta))
        
        // Add to conversation
        conversation.append(Conversation.Item(
            message: .user(input),
            transcript: input
        ))
        
        await requestModel()
    }
    
    private func requestModel() async {
        currentStage = .modelThinking

        let request = await buildModelRequest()

        // Capture continuation and modelClient locally to avoid actor boundary crossing
        let continuation = eventContinuation
        let client = modelClient

        // Use structured concurrency - Task inherits actor context
        // Agent actor methods are serialized, so state access is safe
        Task {
            do {
                let response = try await client.sendRequest(request) { chunk, isReasoning, _ in
                    // Forward the delta chunk from model client immediately
                    let delta = TranscriptDelta(content: chunk, isComplete: false, source: .assistant(isReasoning: isReasoning))
                    continuation.yield(.transcriptDelta(delta))
                }

                // Signal completion of the transcript stream
                let finalDelta = TranscriptDelta(content: "", isComplete: true, source: .assistant(isReasoning: false))
                continuation.yield(.transcriptDelta(finalDelta))

                await handleModelResponse(.success(response))
            } catch {
                await handleModelResponse(.failure(error))
            }
        }
    }
    
    private func buildModelRequest() async -> ModelRequest {
        let messages = conversation.map { $0.message }
        let tools = await toolManager.definitions()
        return ModelRequest(messages: messages, tools: tools)
    }
    
    private func handleModelResponse(_ result: Result<ModelClientResponse, Error>) async {
        switch result {
        case .failure(let error):
            if let modelError = error as? any ModelProviderError {
                eventContinuation.yield(.error(modelError))
            }
            await completeAgentLoop()
            
        case .success(let response):
            // Add to conversation
            let message: ModelMessage
            if let opaque = response.opaqueMessage {
                message = .opaque(opaque)
            } else {
                message = .assistant(response.transcript)
            }
            
            conversation.append(Conversation.Item(
                message: message,
                transcript: response.transcript
            ))
            
            // Check if tool execution is needed
            if response.finishReason == .toolCalls && !response.toolCalls.isEmpty {
                currentStage = .runningTools
                await handleToolCalls(response.toolCalls)
            } else {
                await completeAgentLoop()
            }
        }
    }
    
    private func handleToolCalls(_ calls: [ToolCallRequest]) async {
        pendingToolCalls = calls.map { $0.id }

        // Capture necessary values to avoid capturing self in concurrent context
        let toolManager = self.toolManager

        await withTaskGroup(of: Void.self) { group in
            for call in calls {
                group.addTask {
                    let result = await toolManager.handleRequest(call) { approval in
                        await self.requestApproval(approval)
                    }
                    await self.handleToolResult(id: call.id, result: result)
                }
            }
        }
    }
    
    private func requestApproval(_ approval: Approval) async -> Bool {
        await withCheckedContinuation { continuation in
            approval.setContinuation(continuation)
            eventContinuation.yield(.toolCallRequest(approval))
        }
    }
    
    private func handleToolResult(id: String, result: ToolResult) async {
        completedToolResults[id] = result
        eventContinuation.yield(.toolCallCompleted(id, result))
        
        // Check if all tools are completed
        let allDone = pendingToolCalls.allSatisfy { completedToolResults.keys.contains($0) }
        guard allDone else { return }
        
        // Add tool results to conversation
        for callId in pendingToolCalls {
            guard let result = completedToolResults[callId] else { continue }
            
            let content: String
            let isError: Bool
            
            switch result {
            case .success(let res):
                content = res
                isError = false
            case .failure(let err):
                content = err.reason
                isError = true
            }
            
            let transcript = isError
                ? "Failed to run a tool, error: \(content)"
                : "Ran a tool, result:\n\(content)"
            
            conversation.append(Conversation.Item(
                message: .tool(ToolCallResult(id: callId, content: content)),
                transcript: transcript
            ))
        }
        
        pendingToolCalls.removeAll()
        completedToolResults.removeAll()
        
        // Continue to next round
        await requestModel()
    }
    
    private func completeAgentLoop() async {
        if let input = pendingInputs.first {
            pendingInputs.removeFirst()
            await processInput(input)
        } else {
            currentStage = .idle
            eventContinuation.yield(.idle)
        }
    }
}
