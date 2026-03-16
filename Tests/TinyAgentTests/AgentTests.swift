import Testing
import Foundation
@testable import TinyAgent

@Suite("Agent Tests")
struct AgentTests {
    
    @Test("MockModelClient returns expected response")
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
            onTranscript: { transcript in
                Task { await holder.set(transcript) }
            }
        )
        
        // Give a moment for the callback to execute
        try await Task.sleep(nanoseconds: 10_000_000)
        
        let receivedTranscript = await holder.value
        
        #expect(response.transcript == expectedResponse, 
                "Response should be '\(expectedResponse)', got '\(response.transcript)'")
        #expect(receivedTranscript == expectedResponse,
                "Transcript callback should receive '\(expectedResponse)', got '\(receivedTranscript ?? "nil")'")
    }
    
    @Test("Agent processes user input")
    func agentProcessesUserInput() async throws {
        let mockClient = MockModelClient(responses: ["Hi there!"])
        let agent = Agent(
            modelClient: mockClient,
            toolManager: ToolManager(),
            systemPrompt: nil
        )
        
        let events = await agent.events
        var eventCount = 0
        
        // Send message and collect events
        await agent.enqueueUserInput("Hello")
        
        let startTime = Date()
        for await event in events {
            eventCount += 1
            if case .idle = event {
                break
            }
            if Date().timeIntervalSince(startTime) > 3.0 {
                break
            }
        }
        
        // We should have received some events
        #expect(eventCount >= 1, "Should have received at least one event, got \(eventCount)")
    }
    
    @Test("Agent emits user and assistant transcripts")
    func agentEmitsTranscripts() async throws {
        let expectedResponse = "Mock response"
        let mockClient = MockModelClient(responses: [expectedResponse])
        let agent = Agent(
            modelClient: mockClient,
            toolManager: ToolManager(),
            systemPrompt: nil
        )
        
        let events = await agent.events
        var hasUserTranscript = false
        var hasAssistantTranscript = false
        
        await agent.enqueueUserInput("Test message")
        
        let startTime = Date()
        for await event in events {
            if Date().timeIntervalSince(startTime) > 3.0 { break }
            
            switch event {
            case .transcriptDelta(let delta):
                if delta.source == .user && delta.content == "Test message" {
                    hasUserTranscript = true
                }
                if delta.source == .assistant && delta.content == expectedResponse {
                    hasAssistantTranscript = true
                }
            case .idle:
                break
            default:
                break
            }
            
            if hasUserTranscript && hasAssistantTranscript {
                break
            }
        }
        
        #expect(hasUserTranscript, "Should have received user transcript")
        #expect(hasAssistantTranscript, "Should have received assistant transcript with: \(expectedResponse)")
    }
}
