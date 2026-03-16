# TinyAgent Swift

A Swift Concurrency-based LLM Agent framework built with Actor model design.

## Architecture

The project is organized into 4 modules:

- **TinyAgentCore**: Core abstractions and logic including state machine, tool system, conversation management, and Model protocol definitions
- **TinyAgent**: Main library that assembles components, provides Session API and built-in tools
- **TinyAgentOpenAI**: OpenAI API client implementation
- **TinyAgentCLI**: Command-line interface tool

## Core Features

- **Actor Model**: Agent is an Actor with message-driven interaction and safe state management
- **AsyncStream**: Uses event streams instead of callbacks, more idiomatic Swift style
- **Tool Approval**: Supports user confirmation for dangerous operations
- **State Machine**: Idle → ModelThinking → RunningTools → Idle
- **Async Streaming**: Supports streaming response transcripts

## Usage Examples

### Consuming Events with AsyncStream

```swift
import TinyAgent

// Create session
var builder = SessionBuilder()
builder.withModelClient(yourModelClient)
builder.withSystemPrompt("You are a helpful assistant")

let session = await builder.build()

// Get event stream
let events = await session.events

// Process events (in separate Task)
Task {
    for await event in events {
        switch event {
        case .idle:
            print("Agent is idle")
            
        case .transcript(let text, let source):
            print("\(source): \(text)")
            
        case .error(let error):
            print("Error: \(error)")
            
        case .toolCallRequest(let approval):
            print("Tool: \(approval.toolName)")
            print("Action: \(approval.what)")
            // Request user confirmation
            approval.approve() // or approval.reject()
            
        case .toolCallCompleted(let id, let result):
            print("Tool \(id) completed")
        }
    }
}

// Send message
await session.sendMessage("Hello!")
```

### UI Integration

```swift
struct ContentView: View {
    @State private var session: Session?
    @State private var messages: [String] = []
    @State private var task: Task<Void, Never>?
    
    func startSession() async {
        var builder = SessionBuilder()
        builder.withModelClient(openAIClient)
        session = await builder.build()
        
        // Listen to events
        let events = await session!.events
        task = Task {
            for await event in events {
                await MainActor.run {
                    handleEvent(event)
                }
            }
        }
    }
    
    func handleEvent(_ event: AgentEvent) {
        switch event {
        case .transcript(let text, _):
            messages.append(text)
        default:
            break
        }
    }
}
```

## Implementing ModelClient

```swift
import TinyAgent

struct MyModelClient: ModelClient {
    func sendRequest(
        _ request: ModelRequest,
        onTranscript: (@Sendable (String) -> Void)?
    ) async throws -> ModelClientResponse {
        // Implement communication with LLM API
        // Call onTranscript for streaming responses
    }
}
```

## Event Types

```swift
public enum AgentEvent {
    case idle                                  // Agent idle
    case transcript(String, TranscriptSource)  // Streaming transcript
    case error(ModelProviderError)             // Error
    case toolCallRequest(Approval)             // Tool call request
    case toolCallCompleted(String, ToolResult) // Tool call completed
}
```

## Build

```bash
swift build
swift test
swift run tiny-agent-cli
```

## Advantages of AsyncStream

1. **Unified consumption interface**: All events processed through `for await` loop
2. **Automatic cancellation**: Event stream ends automatically when Task is cancelled
3. **Type safety**: Compiler ensures all event types are handled
4. **Easy composition**: Can be combined with other AsyncSequence operators
