# Agent Instructions for TinyAgent Swift

## Build Commands

```bash
# Build the project
swift build

# Run all tests
swift test

# Run a single test by target name
swift test --filter TinyAgentTests

# Run a specific test
swift test --filter SessionTests

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

- **TinyAgentCore**: Core abstractions and logic
  - Model protocols and types (ModelClient, ModelRequest, etc.)
  - Agent actor with state machine
  - Tool system (Tool protocol, ToolManager, Approval)
  - Conversation management

- **TinyAgent**: Main library that assembles components
  - Session API (Session, SessionBuilder)
  - Built-in tools (ShellTool, GlobTool, ReadFileTool)
  - Re-exports TinyAgentCore types via `@_exported import`

- **TinyAgentOpenAI**: OpenAI API client implementation
  - OpenAIModelClient implementing ModelClient protocol

- **TinyAgentCLI**: Executable target for command-line usage

## Code Style Guidelines

### Imports
- Import Foundation first for system types
- Import module dependencies as needed
- TinyAgent uses `@_exported import TinyAgentCore` so you only need `import TinyAgent`
- Example:
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

### Error Handling
- Define domain-specific error types conforming to appropriate protocols
- Use `Result<T, Error>` for operations that can fail
- Propagate errors with `throws` or handle with do-catch
- Example:
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
- Example:
  ```swift
  public enum AgentEvent: Sendable {
      case idle                                    // Agent is idle
      case transcript(String, TranscriptSource)   // Streaming transcript
      case error(any ModelProviderError)          // Error occurred
  }
  ```

### Protocols
- Define associated types with descriptive names
- Use `any` keyword for protocol types when needed
- Mark protocols with `Sendable` when appropriate
- Example:
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
- Use `[weak self]` in closures to avoid retain cycles

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
- Place tests in `Tests/` directory
- Import `@testable import TinyAgent` to test internal members
- **Test-only helpers (e.g., MockModelClient) must be placed in Test Targets**, not in Source Targets:
  ```
  Tests/TinyAgentTests/
  ├── MockModelClient.swift  // ✓ Correct: Test-only helper
  └── SessionTests.swift

  Sources/TinyAgent/
  └── MockModelClient.swift  // ✗ Wrong: Don't ship test code in product
  ```
- Test targets should use `@testable import` to access internal members

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

## Key Patterns

### Module Organization
- **Core**: Define protocols and core logic, minimal dependencies
- **TinyAgent**: Assemble components, provide high-level API
  - Uses `@_exported import TinyAgentCore` so users only need one import
- **TinyAgentOpenAI**: External service implementations

### Event Streaming
- `Agent` actor exposes `AsyncStream<AgentEvent>` for event consumption
- Use `eventContinuation.yield()` to emit events
- Events are consumed with `for await` loops

### Tool System
- Tools implement the `Tool` protocol
- Tools return `ToolResult` (Result<String, ToolError>)
- Dangerous tools return `Approval` from `makeApproval()` to require user confirmation
- `ToolManager` handles tool execution with approval flow
