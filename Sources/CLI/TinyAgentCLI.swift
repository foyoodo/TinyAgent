import Foundation
import TinyAgent

/// Simple mock model client with streaming simulation
/// Note: Struct is implicitly Sendable (no mutable state), avoiding actor serialization
struct MockModelClient: ModelClient {
    func sendRequest(
        _ request: ModelRequest,
        onTranscript: (@Sendable (String) -> Void)?
    ) async throws -> ModelClientResponse {
        let response = "I'm a mock model. To use real LLMs, implement a proper ModelClient."

        // Stream each character with a small delay
        for char in response {
            onTranscript?(String(char))
            // Yield control back to the runtime for immediate delivery
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

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
        // Tracks whether we've printed the assistant prefix for the current streaming response
        var assistantPrefixPrinted = false

        for await event in events {
            switch event {
            case .idle:
                print("\n[Agent is idle, waiting for input...]")
                // Reset the prefix flag when agent becomes idle
                assistantPrefixPrinted = false

            case .transcriptDelta(let delta):
                switch delta.source {
                case .user:
                    // User input is always complete, print directly
                    print("User: \(delta.content)")
                case .assistant:
                    if delta.isComplete {
                        // Streaming finished, print newline and reset flag
                        print("")
                        assistantPrefixPrinted = false
                    } else {
                        // Print prefix on first chunk, then just append content
                        if !assistantPrefixPrinted {
                            print("Assistant: ", terminator: "")
                            assistantPrefixPrinted = true
                        }
                        print(delta.content, terminator: "")
                        // Force stdout flush for real-time streaming display
                        fflush(stdout)
                    }
                }

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
