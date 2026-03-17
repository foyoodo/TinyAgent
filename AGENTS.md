# Agent Instructions for TinyAgent

## Project Overview

TinyAgent is a Swift Concurrency-based LLM Agent framework built with the Actor model. It provides a robust, type-safe, and composable architecture for building AI-powered applications with tool calling capabilities.

### Key Features

- **Actor Model Design**: Safe state isolation using Swift Actors with message-driven interactions
- **Event Streaming**: AsyncStream-based event handling for real-time responses and streaming transcripts
- **Tool System**: Extensible tool protocol with automatic schema generation and user approval flow
- **State Machine**: Clear agent lifecycle (Idle → ModelThinking → RunningTools → Idle)
- **Built-in Tools**: Shell command execution, file globbing, and file reading with smart approval logic
- **OpenAI Compatible**: Ready-to-use OpenAI API client with SSE streaming support
- **Mock Client**: Built-in mock model client for testing without API keys

### Technology Stack

- **Language**: Swift 6.0+
- **Platform**: macOS 15.0+
- **Build System**: Swift Package Manager (SPM)
- **Testing Framework**: Swift Testing (modern replacement for XCTest)
- **Concurrency**: Swift Actors, async/await, AsyncStream

## Build Commands

```bash
# Build the project
swift build

# Run all tests
swift test

# Run a single test by target name
swift test --filter TinyAgentTests

# Run a specific test suite
swift test --filter SessionTests
swift test --filter AgentTests
swift test --filter ToolTests
swift test --filter OpenAIModelClientTests

# Run a specific test function
swift test --filter SessionTests.sessionBuilderCreatesSession

# Run the CLI
swift run tiny-agent-cli

# Build in release mode
swift build -c release

# Clean build artifacts
swift package clean
```

## Project Structure

This is a Swift Package Manager project with 4 modules:

### TinyAgentCore (Sources/Core/)

Core abstractions and logic with minimal dependencies:

- **Agent.swift**: Main `Agent` actor implementing the state machine and event streaming
- **AgentBuilder.swift**: Builder pattern for constructing Agent instances
- **Tool.swift**: `Tool` protocol, `ToolManager` actor, `Approval` class, and `ToolError`
- **Model.swift**: Model protocols (`ModelClient`, `ModelProvider`), request/response types, and error types
- **Conversation.swift**: `Conversation` struct for managing message history

Key types:
- `Agent`: Actor with state machine (idle → modelThinking → runningTools)
- `AgentEvent`: Event enum (idle, transcriptDelta, error, toolCallRequest, toolCallCompleted)
- `Tool`: Protocol for implementating custom tools
- `ModelClient`: Protocol for LLM API clients

### TinyAgent (Sources/TinyAgent/)

Main library that assembles components and provides high-level API:

- **Session.swift**: `Session` actor and `SessionBuilder` - the primary user-facing API
- **ShellTool.swift**: Executes shell commands (requires approval)
- **GlobTool.swift**: Finds files matching patterns (no approval needed)
- **ReadFileTool.swift**: Reads file contents (requires approval for sensitive files)

Uses `@_exported import TinyAgentCore` so users only need `import TinyAgent`.

### TinyAgentOpenAI (Sources/OpenAI/)

OpenAI API client implementation:

- **OpenAIModelClient.swift**: `OpenAIModelClient` actor implementing `ModelClient` protocol
- **Types.swift**: OpenAI-specific request/response types and `AnyCodable` helper
- **Config.swift**: `OpenAIConfig` for API configuration
- **OpenAIError.swift**: `OpenAIError` conforming to `ModelProviderError`
- **SSEParser.swift**: Server-Sent Events parser for streaming responses

### TinyAgentCLI (Sources/CLI/)

Command-line interface executable:

- **TinyAgentCLI.swift**: CLI entry point with `MockModelClient` fallback

Environment variables:
- `OPENAI_API_KEY` - Required for OpenAI API
- `OPENAI_BASE_URL` - Optional (default: https://api.openai.com/v1)
- `OPENAI_MODEL` - Optional (default: gpt-4)
- `OPENAI_USER_AGENT` - Optional custom User-Agent header

### Tests (Tests/TinyAgentTests/)

Test suite using Swift Testing framework:

- **MockModelClient.swift**: Mock implementation of `ModelClient` for testing
- **SessionTests.swift**: Tests for Session API
- **AgentTests.swift**: Tests for Agent actor and event streaming
- **ToolTests.swift**: Tests for built-in tools (ShellTool, GlobTool, ReadFileTool)
- **OpenAIModelClientTests.swift**: Tests for OpenAI types and SSE parsing

## Architecture Patterns

### Agent State Machine

```
┌─────┐    enqueueUserInput     ┌─────────────────┐
│idle │ ──────────────────────> │ processInput()  │
└─────┘                         └────────┬────────┘
    ▲                                    │
    │                                    ▼
    │                         ┌─────────────────┐
    │                         │ modelThinking   │
    │                         │ (streaming)     │
    │                         └────────┬────────┘
    │                                    │
    │         ┌────────────┐             │ tool calls
    │         │   stop     │             │
    └─────────┤            │<────────────┤
              └────────────┘             ▼
                              ┌─────────────────┐
                              │ runningTools    │
                              │ (parallel exec) │
                              └────────┬────────┘
                                       │
                                       │ all done
                                       ▼
                              ┌─────────────────┐
                              │ requestModel()  │
                              └─────────────────┘
```

### Event Streaming

All events flow through a single `AsyncStream<AgentEvent>`:

```swift
let events = await session.events
for await event in events {
    switch event {
    case .idle:
        // Agent is ready
    case .transcriptDelta(let delta):
        // Streaming content chunk
    case .error(let error):
        // Error occurred
    case .toolCallRequest(let approval):
        // Tool needs approval
    case .toolCallCompleted(let id, let result):
        // Tool finished
    }
}
```

### Tool System

Tools implement the `Tool` protocol:

```swift
public protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameterSchema: [String: Sendable] { get }
    
    func makeApproval(input: [String: Sendable]) -> Approval?
    func execute(input: [String: Sendable]) async -> ToolResult
}
```

Approval flow for dangerous operations:
1. Tool returns `Approval` from `makeApproval()` if user confirmation needed
2. Agent emits `.toolCallRequest(approval)` event
3. User calls `approval.approve()` or `approval.reject()`
4. Tool only executes if approved

## Code Style Guidelines

### Imports

- Import `Foundation` first for system types
- Import module dependencies as needed
- TinyAgent uses `@_exported import TinyAgentCore` so you only need `import TinyAgent`

```swift
import TinyAgent  // Also brings in Core types
```

### Types & Naming

- Use PascalCase for types (structs, classes, enums, protocols)
- Use camelCase for functions, properties, variables
- Prefix boolean properties with `is` (e.g., `isAlive`)
- Protocol names describe capabilities (e.g., `ModelClient`)
- Error types end with `Error` (e.g., `ToolError`)

### Sendable & Concurrency

- Always mark types as `Sendable` when sharing across concurrency domains
- Use `@unchecked Sendable` only when necessary with proper documentation
- Prefer actors over locks for state isolation
- Use `sending` keyword for ownership transfer in function parameters
- Use `[weak self]` in closures to avoid retain cycles

### Error Handling

- Define domain-specific error types conforming to appropriate protocols
- Use `Result<T, Error>` for operations that can fail
- Propagate errors with `throws` or handle with do-catch

```swift
public struct ToolError: Error, Sendable {
    public let kind: ToolErrorKind
    public let reason: String
}
```

### Enums

- Use enums for state machines and event types
- Always conform to `Sendable` for public enums
- Document each case with inline comments

```swift
public enum AgentEvent: Sendable {
    case idle                                   // Agent enters idle state
    case transcriptDelta(TranscriptDelta)       // Streaming text chunk
    case error(any ModelProviderError)          // Error occurred
    case toolCallRequest(Approval)              // Tool requires approval
    case toolCallCompleted(String, ToolResult)  // Tool execution completed
}
```

### Protocols

- Define associated types with descriptive names
- Use `any` keyword for protocol types when needed
- Mark protocols with `Sendable` when appropriate

```swift
public protocol ModelClient: Sendable {
    func sendRequest(
        _ request: ModelRequest,
        onTranscript: (@Sendable (String) -> Void)?
    ) async throws -> ModelClientResponse
}
```

### Async/Await Patterns

- Use `async throws` for async operations that can fail
- Use `AsyncStream` for event streams and continuous data
- Prefer `withTaskGroup` for parallel async operations

### Access Control

- Default to `internal`, use `public` for API surface
- Use `private` for implementation details within a type
- Use `fileprivate` only when truly necessary

### Formatting

- 4 spaces for indentation
- Opening braces on same line
- One blank line between type definitions
- Trailing commas in multi-line collections

### Testing

- Use Swift Testing framework (`import Testing`)
- Use `@Test` attribute for test functions
- Use `@Suite` for organizing test groups
- Place tests in `Tests/` directory
- Import `@testable import TinyAgent` to test internal members
- **Test-only helpers must be placed in Test Targets**, not in Source Targets:
  ```
  Tests/TinyAgentTests/
  ├── MockModelClient.swift  // ✓ Correct: Test-only helper
  └── SessionTests.swift
  ```

### Documentation

- Use `///` for public API documentation
- Document parameters and return values
- Include usage examples for complex APIs
- Comment complex business logic inline

### Comments

- Use English for all documentation and comments
- Use clear, descriptive comments for domain concepts
- Use English for error messages, user-facing text, and terminology
- Use English for TODOs and FIXMEs

## Testing Strategy

### Unit Tests

- Mock external dependencies (e.g., `MockModelClient`)
- Test each component in isolation
- Use async/await patterns for testing async code

### Running Tests

```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test
swift test --filter SessionTests.sessionBuilderCreatesSession
```

## Security Considerations

### Tool Approval

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

## Key Implementation Details

### SSE (Server-Sent Events) Streaming

The OpenAI client uses SSE for streaming responses:

1. `SSEParser` actor parses SSE format line by line
2. Each SSE event contains JSON data
3. `Delta` type handles both `content` and `reasoning_content` fields
4. Tool calls are accumulated across multiple chunks

### Conversation Management

- `Conversation` stores `Item` structs with both `ModelMessage` and transcript
- Messages are formatted for API requests
- Transcripts are for display/debugging

### State Isolation

- `Agent` is an actor - all state access is serialized
- `ToolManager` is an actor - tool registration/execution is serialized
- `Session` is an actor - provides thread-safe event access
- Event continuation is captured locally to avoid actor boundary crossing
