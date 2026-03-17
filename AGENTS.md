# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TinyAgent is a Swift 6 Concurrency-based LLM Agent framework built with the Actor model. It provides a type-safe, composable architecture for building AI-powered applications with tool calling capabilities.

- **Language**: Swift 6.0+ with strict concurrency checking
- **Platform**: macOS 15.0+
- **Build System**: Swift Package Manager
- **Testing**: Swift Testing framework

## Build Commands

```bash
# Build
swift build

# Run tests
swift test

# Run specific test
swift test --filter SessionTests.sessionBuilderCreatesSession

# Run test suite
swift test --filter AgentTests

# Run CLI
swift run tiny-agent-cli

# Clean
swift package clean
```

## Architecture

### Module Structure

| Module | Path | Purpose |
|--------|------|---------|
| TinyAgentCore | Sources/Core/ | Core abstractions: Agent, Tool, ModelClient |
| TinyAgent | Sources/TinyAgent/ | High-level Session API + built-in tools |
| TinyAgentOpenAI | Sources/OpenAI/ | OpenAI API client with SSE streaming |
| TinyAgentCLI | Sources/CLI/ | CLI executable |

### Key Actors

- **Agent** (`Sources/Core/Agent.swift`): Main actor implementing state machine (idle → modelThinking → runningTools)
- **ToolManager** (`Sources/Core/Tool.swift`): Manages tool registration and execution
- **Session** (`Sources/TinyAgent/Session.swift`): User-facing facade over Agent
- **OpenAIModelClient** (`Sources/OpenAI/OpenAIModelClient.swift`): ModelClient implementation with SSE streaming

### State Machine

```
idle ──enqueueUserInput()──> processInput() ──> modelThinking
  ▲                                                 │
  │                                                 │ tool calls
  │                                                 ▼
  └─────────────────────────────────────── runningTools (parallel)
                                                │
                                                │ all done
                                                ▼
                                         requestModel()
```

### Event Streaming

All events flow through `AsyncStream<AgentEvent>`:

```swift
let events = await session.events
for await event in events {
    switch event {
    case .idle: break
    case .transcriptDelta(let delta): // streaming chunk
    case .error(let error):
    case .toolCallRequest(let approval): // needs user approval
    case .toolCallCompleted(let id, let result):
    }
}
```

## Concurrency Patterns

### Swift 6 Concurrency Rules

1. **Prefer structured concurrency**: Use `Task` over `Task.detached` unless you have a specific reason
2. **Actor isolation**: All stateful components are actors (Agent, ToolManager, Session)
3. **Sendable conformance**: All public types conform to `Sendable`; use `@unchecked Sendable` only with documented safety invariants
4. **Avoid `[weak self]` in structured contexts**: Only use in closures that may outlive the actor

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

**Approval flow** for dangerous operations:
1. Tool returns `Approval` from `makeApproval()` if confirmation needed
2. Agent emits `.toolCallRequest(approval)` event
3. User calls `approval.approve()` or `approval.reject()`
4. Tool only executes if approved

### Testing

- Use `@testable import TinyAgent` to test internal members
- Place test-only helpers in Test Targets only (e.g., `MockModelClient.swift`)
- Mock external dependencies (ModelClient) for unit tests

## CLI Environment Variables

- `OPENAI_API_KEY` - Required for OpenAI API
- `OPENAI_BASE_URL` - Optional (default: https://api.openai.com/v1)
- `OPENAI_MODEL` - Optional (default: gpt-4)
- `OPENAI_USER_AGENT` - Optional

## Key Implementation Details

### SSE Streaming

`OpenAIModelClient` uses SSE for streaming responses:
1. `SSEParser` actor parses SSE format line by line
2. `Delta` type handles both `content` and `reasoning_content` fields
3. Tool calls are accumulated across multiple chunks

### State Isolation

- `Agent` is an actor - all state access is serialized through the actor's mailbox
- `ToolManager` is an actor - tool registration/execution is serialized
- Event continuation is captured locally to avoid actor boundary crossing issues

### Security

- **ShellTool**: Always requires approval
- **ReadFileTool**: Requires approval for files outside cwd or matching sensitive patterns
- **GlobTool**: No approval needed (read-only)
