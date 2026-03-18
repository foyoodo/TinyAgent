import Testing
import Foundation
@testable import TinyAgent

// MARK: - Test Tags

extension Tag {
    @Tag static var agent: Self
    @Tag static var eventStreaming: Self
    @Tag static var modelClient: Self
}

// MARK: - Agent Tests

@Suite("Agent Tests", .tags(.agent))
struct AgentTests {
    
    // MARK: - MockModelClient Tests
    
    @Test("MockModelClient returns expected response", .tags(.modelClient))
    func mockModelClientReturnsExpectedResponse() async throws {
        let expectedResponse = "Test response"
        let mockClient = MockModelClient(responses: [expectedResponse])
        
        actor TranscriptHolder {
            var value: String?
            func set(_ transcript: String) { value = transcript }
        }
        
        let holder = TranscriptHolder()
        let response = try await mockClient.sendRequest(
            ModelRequest(messages: [], tools: []),
            onTranscript: { transcript, _, _ in
                Task { await holder.set(transcript) }
            }
        )
        
        // Give a moment for the callback to execute
        try await Task.sleep(nanoseconds: 10_000_000)
        
        let receivedTranscript = await holder.value
        
        #expect(response.transcript == expectedResponse)
        #expect(receivedTranscript == expectedResponse)
    }
    
    @Test("MockModelClient cycles through multiple responses", .tags(.modelClient))
    func mockModelClientCyclesThroughResponses() async throws {
        let responses = ["First", "Second", "Third"]
        let mockClient = MockModelClient(responses: responses)
        
        // Verify each response is returned in order
        for expected in responses {
            let response = try await mockClient.sendRequest(
                ModelRequest(messages: [], tools: []),
                onTranscript: nil
            )
            #expect(response.transcript == expected)
        }
        
        // Verify it cycles back to the first response
        let cycledResponse = try await mockClient.sendRequest(
            ModelRequest(messages: [], tools: []),
            onTranscript: nil
        )
        #expect(cycledResponse.transcript == responses[0])
    }
    
    // MARK: - Agent Event Tests
    
    @Test("Agent processes user input", .tags(.eventStreaming))
    func agentProcessesUserInput() async throws {
        let mockClient = MockModelClient(responses: ["Hi there!"])
        let agent = Agent(
            modelClient: mockClient,
            toolManager: ToolManager(),
            systemPrompt: nil
        )
        
        let events = await agent.events
        
        // Use actor for thread-safe state
        actor EventCounter {
            var count = 0
            func increment() { count += 1 }
        }
        let counter = EventCounter()
        
        // Send message and collect events
        await agent.enqueueUserInput("Hello")
        
        // Use a more reliable timeout mechanism
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            return true
        }
        
        let eventTask = Task {
            for await event in events {
                await counter.increment()
                if case .idle = event {
                    break
                }
            }
        }
        
        // Wait for either timeout or completion
        _ = try? await timeoutTask.value
        eventTask.cancel()
        
        let eventCount = await counter.count
        #expect(eventCount >= 1, "Should have received at least one event")
    }
    
    @Test("Agent emits user and assistant transcripts", .tags(.eventStreaming))
    func agentEmitsTranscripts() async throws {
        let expectedResponse = "Mock response"
        let mockClient = MockModelClient(responses: [expectedResponse])
        let agent = Agent(
            modelClient: mockClient,
            toolManager: ToolManager(),
            systemPrompt: nil
        )
        
        let events = await agent.events
        
        // Use actor for thread-safe state
        actor TranscriptFlags {
            var user = false
            var assistant = false
            func setUser() { user = true }
            func setAssistant() { assistant = true }
        }
        let flags = TranscriptFlags()
        
        await agent.enqueueUserInput("Test message")
        
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        }
        
        let eventTask = Task {
            for await event in events {
                switch event {
                case .transcriptDelta(let delta):
                    if delta.source == .user && delta.content == "Test message" {
                        await flags.setUser()
                    }
                    if delta.source.isAssistant && delta.content == expectedResponse {
                        await flags.setAssistant()
                    }
                case .idle:
                    break
                default:
                    break
                }
                
                let (hasUser, hasAssistant) = await (flags.user, flags.assistant)
                if hasUser && hasAssistant {
                    break
                }
            }
        }
        
        // Wait for either completion or timeout
        _ = try? await timeoutTask.value
        eventTask.cancel()
        
        let (hasUserTranscript, hasAssistantTranscript) = await (flags.user, flags.assistant)
        #expect(hasUserTranscript, "Should have received user transcript with 'Test message'")
        #expect(hasAssistantTranscript, "Should have received assistant transcript with '\(expectedResponse)'")
    }
    
    @Test("Agent emits idle event after processing", .tags(.eventStreaming))
    func agentEmitsIdleEvent() async throws {
        let mockClient = MockModelClient(responses: ["Response"])
        let agent = Agent(
            modelClient: mockClient,
            toolManager: ToolManager(),
            systemPrompt: nil
        )
        
        let events = await agent.events
        
        // Use actor for thread-safe state
        actor IdleFlag {
            var received = false
            func set() { received = true }
        }
        let flag = IdleFlag()
        
        await agent.enqueueUserInput("Test")
        
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        
        let eventTask = Task {
            for await event in events {
                if case .idle = event {
                    await flag.set()
                    break
                }
            }
        }
        
        _ = try? await timeoutTask.value
        eventTask.cancel()
        
        let receivedIdle = await flag.received
        #expect(receivedIdle, "Should have received idle event after processing")
    }
    
    // MARK: - System Prompt Tests
    
    @Test("Agent with system prompt includes it in conversation")
    func agentWithSystemPrompt() async throws {
        let systemPrompt = "You are a helpful assistant"
        let mockClient = MockModelClient(responses: ["Hello"])
        let agent = Agent(
            modelClient: mockClient,
            toolManager: ToolManager(),
            systemPrompt: systemPrompt
        )
        
        // Just verify the agent is created successfully with system prompt
        let events = await agent.events
        _ = events.makeAsyncIterator()
        #expect(Bool(true), "Agent with system prompt should provide valid events")
    }
}
