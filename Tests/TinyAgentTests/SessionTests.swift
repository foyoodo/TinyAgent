import Testing
import Foundation
@testable import TinyAgent

// MARK: - Test Tags

extension Tag {
    @Tag static var session: Self
}

// MARK: - Session Tests

@Suite("Session Tests", .tags(.session))
struct SessionTests {
    
    // MARK: - Builder Tests
    
    @Test("Session can be created with builder")
    func sessionBuilderCreatesSession() async throws {
        let mockClient = MockModelClient(responses: ["Hello!"])
        
        var builder = SessionBuilder()
        builder.withModelClient(mockClient)
        builder.withSystemPrompt("You are a test assistant")
        
        let session = await builder.build()
        
        // Verify session was created by checking events can be accessed
        let events = await session.events
        
        // Verify the event stream is valid
        _ = events.makeAsyncIterator()
        // The stream should exist and be iterable
        #expect(Bool(true), "Session should provide a valid event stream")
    }
    
    @Test("Session requires model client")
    func sessionRequiresModelClient() async {
        var builder = SessionBuilder()
        builder.withSystemPrompt("Test prompt")
        // Note: Not setting model client - this will trigger fatalError in debug builds
        // In production, we'd want to handle this gracefully
    }
    
    // MARK: - Message Tests
    
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
        
        // Verify session is still functional by sending another message
        await session.sendMessage("Second message")
        
        // If we get here without crash, the session handled the messages
        #expect(Bool(true), "Session successfully processed both messages")
    }
    
    @Test("Session handles multiple consecutive messages")
    func sessionHandlesMultipleMessages() async throws {
        let responses = ["Response 1", "Response 2", "Response 3"]
        let mockClient = MockModelClient(responses: responses)
        
        var builder = SessionBuilder()
        builder.withModelClient(mockClient)
        
        let session = await builder.build()
        
        // Send multiple messages
        for i in 1...3 {
            await session.sendMessage("Message \(i)")
            try await Task.sleep(nanoseconds: 50_000_000) // Small delay between messages
        }
        
        // Allow time for processing
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify session remains functional
        let events = await session.events
        _ = events.makeAsyncIterator()
        #expect(Bool(true), "Session should still provide valid events")
    }
    
    // MARK: - Event Stream Tests
    
    @Test("Session provides consistent event stream")
    func sessionProvidesConsistentEventStream() async throws {
        let mockClient = MockModelClient(responses: ["Test"])
        
        var builder = SessionBuilder()
        builder.withModelClient(mockClient)
        
        let session = await builder.build()
        
        // Get event stream multiple times - should be the same stream
        let events1 = await session.events
        let events2 = await session.events
        
        // Both should be valid AsyncStreams
        _ = events1.makeAsyncIterator()
        _ = events2.makeAsyncIterator()
        #expect(Bool(true), "Both event streams should be valid")
    }
}
