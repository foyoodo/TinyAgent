import Foundation
import TinyAgent

/// Simple mock model client for demonstration
actor MockModelClient: ModelClient {
    func sendRequest(
        _ request: ModelRequest,
        onTranscript: (@Sendable (String) -> Void)?
    ) async throws -> ModelClientResponse {
        let response = "I'm a mock model. To use real LLMs, implement a proper ModelClient."
        onTranscript?(response)
        return ModelClientResponse(
            transcript: response,
            opaqueMessage: nil,
            toolCalls: [],
            finishReason: .stop
        )
    }
}

@main
struct TinyAgentCLI {
    static func main() async {
        print("TinyAgent Swift CLI")
        print("=====================")
        print("")
        print("Note: This is a skeleton implementation.")
        print("You need to implement a ModelClient to use it with real LLMs.")
        print("")

        // Create session
        var builder = SessionBuilder()
        builder.withModelClient(MockModelClient())
        builder.withSystemPrompt("You are a helpful assistant")
        
        let session = await builder.build()
        
        // Get event stream
        let events = await session.events
        
        // Start event processing loop
        Task {
            await handleEvents(events)
        }
        
        // Simulate user interaction
        print("Type your message (or 'exit' to exit):")
        
        while let line = readLine() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.lowercased() == "exit" {
                break
            }
            
            if !trimmed.isEmpty {
                await session.sendMessage(trimmed)
            }
        }
    }
    
    static func handleEvents(_ events: AsyncStream<AgentEvent>) async {
        for await event in events {
            switch event {
            case .idle:
                print("\n[Agent is idle, waiting for input...]")
                
            case .transcript(let text, let source):
                let prefix = source == .user ? "User" : "Assistant"
                print("\(prefix): \(text)")
                
            case .error(let error):
                print("[Error]: \(error)")
                
            case .toolCallRequest(let approval):
                print("\n[Tool Call Request]")
                print("Tool: \(approval.toolName)")
                print("Justification: \(approval.justification)")
                print("Action: \(approval.what)")
                // Simplified: auto-approve
                approval.approve()
                
            case .toolCallCompleted(let id, let result):
                switch result {
                case .success(let output):
                    print("[Tool \(id) completed successfully]")
                case .failure(let error):
                    print("[Tool \(id) failed]: \(error.reason)")
                }
            }
        }
    }
}
