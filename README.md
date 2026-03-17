# TinyAgent

A Swift Concurrency-based LLM Agent framework built with the Actor model. TinyAgent provides a robust, type-safe, and composable architecture for building AI-powered applications with tool calling capabilities.

## Features

- **Actor Model Design**: Safe state isolation using Swift Actors with message-driven interactions
- **Event Streaming**: AsyncStream-based event handling for real-time responses and streaming transcripts
- **Tool System**: Extensible tool protocol with automatic schema generation and user approval flow
- **State Machine**: Clear agent lifecycle (Idle → ModelThinking → RunningTools → Idle)
- **Built-in Tools**: Shell command execution, file globbing, and file reading with smart approval logic
- **OpenAI Compatible**: Ready-to-use OpenAI API client with SSE streaming support
- **Mock Client**: Built-in mock model client for testing without API keys
- **Swift 6 Ready**: Full Sendable conformance and strict concurrency checking

## Requirements

- Swift 6.0+
- macOS 15.0+

## Installation

Add TinyAgent to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/TinyAgent.git", from: "1.0.0")
]
```

Then add the desired products to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "TinyAgent", package: "TinyAgent"),
        .product(name: "TinyAgentOpenAI", package: "TinyAgent")
    ]
)
```

## Project Structure

The framework is organized into four modules:

| Module | Description |
|--------|-------------|
| **TinyAgentCore** | Core abstractions: `Agent`, `Tool`, `ModelClient`, `Conversation` |
| **TinyAgent** | High-level API with `Session` and built-in tools |
| **TinyAgentOpenAI** | OpenAI API client implementation |
| **TinyAgentCLI** | Command-line interface executable |

## Quick Start

### Basic Usage

```swift
import TinyAgent
import TinyAgentOpenAI

// Create an OpenAI model client
let modelClient = OpenAIModelClient(
    apiKey: "your-api-key",
    model: "gpt-4"
)

// Build a session with built-in tools
var builder = SessionBuilder()
builder.withModelClient(modelClient)
builder.withSystemPrompt("You are a helpful coding assistant")

let session = await builder.build()

// Listen for events
let events = await session.events
Task.detached { @Sendable in
    for await event in events {
        handleEvent(event)
    }
}

// Send a message
await session.sendMessage("List all Swift files in the current directory")
```

### Handling Events

```swift
func handleEvent(_ event: AgentEvent) {
    switch event {
    case .idle:
        print("Agent is ready for input")
        
    case .transcriptDelta(let delta):
        if delta.source == .assistant {
            print(delta.content, terminator: "")
        }
        
    case .error(let error):
        print("Error: \(error)")
        
    case .toolCallRequest(let approval):
        print("\nTool request: \(approval.toolName)")
        print("Action: \(approval.what)")
        // Require user confirmation for sensitive operations
        approval.approve() // or approval.reject()
        
    case .toolCallCompleted(let id, let result):
        switch result {
        case .success(let output):
            print("Tool result: \(output)")
        case .failure(let error):
            print("Tool failed: \(error.reason)")
        }
    }
}
```

## Architecture

### Agent State Machine

```
┌─────┐    enqueueUserInput     ┌─────────────────┐
│idle │ ──────────────────────> │  processInput() │
└─────┘                         └────────┬────────┘
    ▲                                    │
    │                                    ▼
    │                         ┌─────────────────┐
    │                         │ modelThinking   │
    │                         │  (streaming)    │
    │                         └────────┬────────┘
    │                                    │
    │         ┌────────────┐             │ tool calls
    │         │    stop    │             │
    └─────────┤            │<────────────┤
              └────────────┘             ▼
                              ┌─────────────────┐
                              │  runningTools   │
                              │ (parallel exec) │
                              └────────┬────────┘
                                       │
                                       │ all done
                                       ▼
                              ┌─────────────────┐
                              │  requestModel() │
                              └─────────────────┘
```

### Event Streaming

All events flow through a single `AsyncStream<AgentEvent>`:

```swift
public enum AgentEvent: Sendable {
    case idle                                    // Agent enters idle state
    case transcriptDelta(TranscriptDelta)       // Streaming text chunk
    case error(any ModelProviderError)          // Error occurred
    case toolCallRequest(Approval)              // Tool requires approval
    case toolCallCompleted(String, ToolResult)  // Tool execution completed
}

public struct TranscriptDelta: Sendable {
    public let content: String       // The text chunk
    public let isComplete: Bool      // True when streaming is complete
    public let source: TranscriptSource  // .user or .assistant
}
```

## Built-in Tools

### ShellTool

Executes shell commands. **Always requires user approval**.

```swift
// The LLM can invoke: {"command": "ls -la"}
// User will be prompted for approval before execution
```

### GlobTool

Finds files matching a pattern (e.g., `*.swift`). No approval required.

```swift
// The LLM can invoke: {"pattern": "*.swift"}
```

### ReadFileTool

Reads file contents. Requires approval when:
- Reading files outside the current working directory
- Reading potentially sensitive files (`.env`, `.ssh`, secrets, etc.)

```swift
// The LLM can invoke: {"path": "Package.swift"}
```

## Creating Custom Tools

Implement the `Tool` protocol:

```swift
import TinyAgent

struct CalculatorTool: Tool {
    let name = "calculator"
    let description = "Perform basic arithmetic calculations"
    
    var parameterSchema: [String: Sendable] {
        [
            "expression": "string (e.g., '2 + 2')"
        ]
    }
    
    func makeApproval(input: [String: Sendable]) -> Approval? {
        // Return nil for safe operations, Approval for dangerous ones
        return nil
    }
    
    func execute(input: [String: Sendable]) async -> ToolResult {
        guard let expression = input["expression"] as? String else {
            return .failure(ToolError(kind: .invalidInput, reason: "Missing expression"))
        }
        
        // Perform calculation...
        return .success("4")
    }
}

// Register with the builder
var builder = SessionBuilder()
builder.withModelClient(modelClient)
builder.withSystemPrompt("You have access to a calculator tool")

// Note: Built-in tools are automatically registered by SessionBuilder
// For custom tools, use AgentBuilder directly
```

## Implementing a Custom ModelClient

```swift
import TinyAgent

struct MyModelClient: ModelClient {
    func sendRequest(
        _ request: ModelRequest,
        onTranscript: (@Sendable (String) -> Void)?
    ) async throws -> ModelClientResponse {
        // Call your LLM API
        // Invoke onTranscript for each streaming chunk
        
        return ModelClientResponse(
            transcript: "Full response text",
            opaqueMessage: nil,
            toolCalls: [],  // Return tool calls if the model requests them
            finishReason: .stop
        )
    }
}
```

## CLI Usage

Build and run the CLI:

```bash
swift build
swift run tiny-agent-cli
```

Configure via environment variables:

```bash
export OPENAI_API_KEY="sk-..."
export OPENAI_BASE_URL="https://api.openai.com/v1"  # Optional
export OPENAI_MODEL="gpt-4"                         # Optional
export OPENAI_USER_AGENT="MyApp/1.0"                # Optional

swift run tiny-agent-cli
```

If `OPENAI_API_KEY` is not set, the CLI falls back to a mock model that demonstrates the streaming behavior.

## Development

### Build Commands

```bash
# Build the project
swift build

# Run all tests
swift test

# Run a specific test suite
swift test --filter SessionTests
swift test --filter AgentTests
swift test --filter ToolTests
swift test --filter OpenAIModelClientTests

# Run a specific test function
swift test --filter SessionTests.sessionBuilderCreatesSession

# Build in release mode
swift build -c release

# Clean build artifacts
swift package clean
```

### Project Structure

```
Sources/
├── Core/               # TinyAgentCore module
│   ├── Agent.swift     # Main actor with state machine
│   ├── AgentBuilder.swift
│   ├── Tool.swift      # Tool protocol and ToolManager
│   ├── Model.swift     # ModelClient protocol and types
│   └── Conversation.swift
├── TinyAgent/          # TinyAgent module
│   ├── Session.swift   # High-level Session API
│   ├── ShellTool.swift
│   ├── GlobTool.swift
│   └── ReadFileTool.swift
├── OpenAI/             # TinyAgentOpenAI module
│   ├── OpenAIModelClient.swift
│   ├── Types.swift
│   ├── Config.swift
│   ├── OpenAIError.swift
│   └── SSEParser.swift
└── CLI/                # TinyAgentCLI executable
    └── TinyAgentCLI.swift

Tests/
└── TinyAgentTests/
    ├── MockModelClient.swift
    ├── AgentTests.swift
    ├── SessionTests.swift
    ├── ToolTests.swift
    └── OpenAIModelClientTests.swift
```

## SwiftUI Integration

```swift
import SwiftUI
import TinyAgent

struct ContentView: View {
    @State private var session: Session?
    @State private var messages: [String] = []
    @State private var inputText = ""
    
    func startSession() async {
        let modelClient = OpenAIModelClient(apiKey: "sk-...")
        
        var builder = SessionBuilder()
        builder.withModelClient(modelClient)
        session = await builder.build()
        
        // Listen to events
        let events = await session!.events
        Task.detached { @Sendable in
            for await event in events {
                await MainActor.run {
                    handleEvent(event)
                }
            }
        }
    }
    
    func handleEvent(_ event: AgentEvent) {
        switch event {
        case .transcriptDelta(let delta):
            if delta.source == .assistant && !delta.isComplete {
                messages.append(delta.content)
            }
        default:
            break
        }
    }
    
    var body: some View {
        VStack {
            List(messages, id: \.self) { msg in
                Text(msg)
            }
            HStack {
                TextField("Message", text: $inputText)
                Button("Send") {
                    Task {
                        await session?.sendMessage(inputText)
                        inputText = ""
                    }
                }
            }
        }
        .task {
            await startSession()
        }
    }
}
```

## Testing

The framework includes a `MockModelClient` for testing:

```swift
import Testing
@testable import TinyAgent

@Test("Agent processes messages")
func testAgent() async throws {
    let mockClient = MockModelClient(responses: ["Hello!"])
    
    var builder = SessionBuilder()
    builder.withModelClient(mockClient)
    
    let session = await builder.build()
    await session.sendMessage("Hi")
    
    // Assert expected behavior...
}
```

Run tests:

```bash
swift test
```

## Why AsyncStream?

The framework uses `AsyncStream` instead of callbacks for several advantages:

1. **Unified Interface**: All events flow through a single `for await` loop
2. **Type Safety**: The compiler ensures all event cases are handled
3. **Automatic Lifecycle**: Stream ends when the Task is cancelled
4. **Composability**: Works seamlessly with other AsyncSequence operators
5. **Swift Idiomatic**: Natural fit with Swift's structured concurrency

## Security Considerations

### Tool Approval System

The framework implements an approval system for potentially dangerous operations:

- **ShellTool**: Always requires approval (executes arbitrary commands)
- **ReadFileTool**: Requires approval when:
  - Reading files outside current working directory
  - Reading files matching sensitive patterns (`.env`, `.ssh`, secrets, etc.)
- **GlobTool**: No approval needed (read-only directory listing)

### API Keys

- Never hardcode API keys in source code
- Use environment variables for configuration
- The CLI reads `OPENAI_API_KEY` from environment

## License

MIT License
