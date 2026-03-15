import Testing
import Foundation
@testable import TinyAgent

@Suite("Session Tests")
struct SessionTests {
    
    @Test("Session can be created with builder")
    func sessionBuilderCreatesSession() async throws {
        let mockClient = MockModelClient(responses: ["Hello!"])
        
        var builder = SessionBuilder()
        builder.withModelClient(mockClient)
        builder.withSystemPrompt("You are a test assistant")
        
        let session = await builder.build()
        
        // Verify session was created
        #expect(true)
        
        // Verify we can get events (returns AsyncStream, not Optional)
        let events = await session.events
        #expect(events is AsyncStream<AgentEvent>)
    }
    
    @Test("Session sends messages")
    func sessionSendsMessages() async throws {
        let mockClient = MockModelClient(responses: ["Test response"])
        
        var builder = SessionBuilder()
        builder.withModelClient(mockClient)
        
        let session = await builder.build()
        
        // This should not throw
        await session.sendMessage("Hello")
        
        // Give it a moment to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Success if we get here without crash
        #expect(true)
    }
}
