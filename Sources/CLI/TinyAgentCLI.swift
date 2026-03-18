import Foundation
import TinyAgent
import TinyAgentOpenAI

/// Reads environment variables from the system
func getEnvironmentVariable(_ name: String) -> String? {
    ProcessInfo.processInfo.environment[name]
}

/// Configuration for the model client
struct ModelClientConfig: Sendable {
    let apiKey: String?
    let baseURL: String?
    let model: String?
    let userAgent: String?

    var isConfigured: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }

    static func fromEnvironment() -> ModelClientConfig {
        ModelClientConfig(
            apiKey: getEnvironmentVariable("OPENAI_API_KEY"),
            baseURL: getEnvironmentVariable("OPENAI_BASE_URL"),
            model: getEnvironmentVariable("OPENAI_MODEL"),
            userAgent: getEnvironmentVariable("OPENAI_USER_AGENT")
        )
    }
}

/// Simple mock model client with word-by-word streaming
/// Falls back when OpenAI is not configured
struct MockModelClient: ModelClient, Sendable {
    func sendRequest(
        _ request: ModelRequest,
        onTranscript: (@Sendable (String, Bool, Bool) -> Void)?
    ) async throws -> ModelClientResponse {
        let response = "I'm a mock model. To use real LLMs, set OPENAI_API_KEY environment variable."

        // Stream word by word with small delays
        let words = response.split(separator: " ").map(String.init)
        for (index, word) in words.enumerated() {
            let isLast = index == words.count - 1
            let content = isLast ? word : word + " "
            // First word is start of message
            onTranscript?(content, false, index == 0)
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms between words
        }

        return ModelClientResponse(
            transcript: response,
            opaqueMessage: nil,
            toolCalls: [],
            finishReason: .stop
        )
    }
}

/// Creates the appropriate model client based on environment configuration
func createModelClient(config: ModelClientConfig) -> any ModelClient {
    guard config.isConfigured else {
        return MockModelClient()
    }

    let baseURL = config.baseURL ?? "https://api.openai.com/v1"
    let model = config.model ?? "gpt-4"

    return OpenAIModelClient(
        apiKey: config.apiKey!,
        baseURL: baseURL,
        model: model,
        userAgent: config.userAgent
    )
}

@main
struct TinyAgentCLI {
    static func main() async {
        print("TinyAgent Swift CLI")
        print("=====================")
        print("")

        // Read configuration from environment
        let config = ModelClientConfig.fromEnvironment()

        if config.isConfigured {
            print("Using OpenAI API")
            if let baseURL = config.baseURL {
                print("  Base URL: \(baseURL)")
            }
            if let model = config.model {
                print("  Model: \(model)")
            }
        } else {
            print("Using Mock Model Client (set OPENAI_API_KEY to use OpenAI)")
            print("")
            print("Environment variables:")
            print("  OPENAI_API_KEY - Your API key (required)")
            print("  OPENAI_BASE_URL - API base URL (default: https://api.openai.com/v1)")
            print("  OPENAI_MODEL - Model name (default: gpt-4)")
            print("  OPENAI_USER_AGENT - Custom User-Agent header")
        }
        print("")

        // Create model client
        let modelClient = createModelClient(config: config)

        // Create session
        var builder = SessionBuilder()
        builder.withModelClient(modelClient)
        builder.withSystemPrompt("You are a helpful assistant")

        let session = await builder.build()

        // Get event stream
        let events = await session.events

        // Start event processing loop in background with proper cancellation support
        let eventTask = Task {
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

        // Cancel the event processing task on exit
        eventTask.cancel()
    }

    static func handleEvents(_ events: AsyncStream<AgentEvent>) async {
        // Track current output mode to detect transitions
        var currentMode: TranscriptSource? = nil

        for await event in events {
            // Check for cancellation at each event
            if Task.isCancelled { break }

            switch event {
            case .idle:
                print("\n[Agent is idle, waiting for input...]")
                currentMode = nil

            case .transcriptDelta(let delta):
                switch delta.source {
                case .user:
                    // User input is always complete, print directly
                    print("User: \(delta.content)")

                case .assistant(let isReasoning):
                    if delta.isComplete {
                        // Streaming finished, print newline and reset state
                        print("")
                        currentMode = nil
                    } else if !delta.content.isEmpty {
                        // Check if this is a new message or mode transition
                        let newMode: TranscriptSource = .assistant(isReasoning: isReasoning)

                        if currentMode != newMode {
                            // Mode changed - print appropriate header
                            if isReasoning {
                                print("Assistant (thinking): ", terminator: "")
                            } else {
                                print("\nAssistant: ", terminator: "")
                            }
                            currentMode = newMode
                        }
                        print(delta.content, terminator: "")
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
                    print("[Tool \(id) completed successfully]: \(output)")
                case .failure(let error):
                    print("[Tool \(id) failed]: \(error.reason)")
                }
            }
        }
    }
}
