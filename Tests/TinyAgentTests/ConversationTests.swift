import Testing
import Foundation
import TinyAgentCore

// MARK: - Test Tags

extension Tag {
    @Tag static var conversation: Self
}

// MARK: - Conversation Tests

@Suite("Conversation Tests", .tags(.conversation))
struct ConversationTests {
    
    // MARK: - Basic Operations
    
    @Test("Can create empty conversation")
    func createEmptyConversation() {
        let conversation = Conversation()
        
        var itemCount = 0
        for _ in conversation {
            itemCount += 1
        }
        
        #expect(itemCount == 0, "New conversation should be empty")
    }
    
    @Test("Can append items to conversation")
    func appendItems() {
        var conversation = Conversation()
        
        let item1 = Conversation.Item(
            message: .user("Hello"),
            transcript: "Hello"
        )
        let item2 = Conversation.Item(
            message: .assistant("Hi there!"),
            transcript: "Hi there!"
        )
        
        conversation.append(item1)
        conversation.append(item2)
        
        var items: [Conversation.Item] = []
        for item in conversation {
            items.append(item)
        }
        
        #expect(items.count == 2, "Should have 2 items")
        #expect(items[0].transcript == "Hello")
        #expect(items[1].transcript == "Hi there!")
    }
    
    @Test("Conversation is a Sequence")
    func conversationIsSequence() {
        var conversation = Conversation()
        
        conversation.append(Conversation.Item(
            message: .system("You are helpful"),
            transcript: "You are helpful"
        ))
        conversation.append(Conversation.Item(
            message: .user("Hello"),
            transcript: "Hello"
        ))
        
        // Test that we can use Sequence methods
        let transcripts = conversation.map { $0.transcript }
        
        #expect(transcripts.count == 2)
        #expect(transcripts == ["You are helpful", "Hello"])
    }
    
    // MARK: - Message Type Tests
    
    @Test("Can store different message types")
    func storeDifferentMessageTypes() {
        var conversation = Conversation()
        
        conversation.append(Conversation.Item(
            message: .system("System prompt"),
            transcript: "System prompt"
        ))
        conversation.append(Conversation.Item(
            message: .user("User message"),
            transcript: "User message"
        ))
        conversation.append(Conversation.Item(
            message: .assistant("Assistant response"),
            transcript: "Assistant response"
        ))
        conversation.append(Conversation.Item(
            message: .tool(ToolCallResult(id: "call-1", content: "Tool result")),
            transcript: "Tool result"
        ))
        conversation.append(Conversation.Item(
            message: .opaque(OpaqueMessage(content: "Opaque content")),
            transcript: "Opaque content"
        ))
        
        let items = Array(conversation)
        
        #expect(items.count == 5, "Should have 5 items")
        
        // Verify each message type is preserved
        if case .system(let content) = items[0].message {
            #expect(content == "System prompt")
        } else {
            Issue.record("First item should be system message")
        }
        
        if case .user(let content) = items[1].message {
            #expect(content == "User message")
        } else {
            Issue.record("Second item should be user message")
        }
        
        if case .assistant(let content) = items[2].message {
            #expect(content == "Assistant response")
        } else {
            Issue.record("Third item should be assistant message")
        }
        
        if case .tool(let result) = items[3].message {
            #expect(result.id == "call-1")
            #expect(result.content == "Tool result")
        } else {
            Issue.record("Fourth item should be tool message")
        }
        
        if case .opaque(let opaque) = items[4].message {
            #expect(opaque.content == "Opaque content")
        } else {
            Issue.record("Fifth item should be opaque message")
        }
    }
    
    // MARK: - Transcript Tests
    
    @Test("Transcript can differ from message content")
    func transcriptDiffersFromContent() throws {
        var conversation = Conversation()
        
        // Sometimes transcript might be formatted differently
        conversation.append(Conversation.Item(
            message: .user("Raw user input"),
            transcript: "Formatted: Raw user input"
        ))
        
        let item = try #require(Array(conversation).first, "Should have one item")
        
        if case .user(let content) = item.message {
            #expect(content == "Raw user input")
        }
        
        #expect(item.transcript == "Formatted: Raw user input")
    }
    
    // MARK: - Conversation Flow Tests
    
    @Test("Simulate typical conversation flow")
    func simulateConversationFlow() {
        var conversation = Conversation()
        
        // System prompt
        conversation.append(Conversation.Item(
            message: .system("You are a helpful assistant"),
            transcript: "System: You are a helpful assistant"
        ))
        
        // User asks a question
        conversation.append(Conversation.Item(
            message: .user("What is Swift?"),
            transcript: "User: What is Swift?"
        ))
        
        // Assistant responds
        conversation.append(Conversation.Item(
            message: .assistant("Swift is a programming language..."),
            transcript: "Assistant: Swift is a programming language..."
        ))
        
        // User follows up
        conversation.append(Conversation.Item(
            message: .user("Tell me more"),
            transcript: "User: Tell me more"
        ))
        
        // Assistant uses a tool
        conversation.append(Conversation.Item(
            message: .tool(ToolCallResult(id: "call-1", content: "Additional info")),
            transcript: "Tool: Additional info"
        ))
        
        // Assistant provides final response
        conversation.append(Conversation.Item(
            message: .assistant("Here is more information..."),
            transcript: "Assistant: Here is more information..."
        ))
        
        let items = Array(conversation)
        
        #expect(items.count == 6, "Should have 6 items in conversation")
        
        // Verify order is preserved
        let expectedOrder: [String] = [
            "System: You are a helpful assistant",
            "User: What is Swift?",
            "Assistant: Swift is a programming language...",
            "User: Tell me more",
            "Tool: Additional info",
            "Assistant: Here is more information...",
        ]
        
        let actualOrder = items.map { $0.transcript }
        #expect(actualOrder == expectedOrder, "Conversation order should be preserved")
    }
    
    // MARK: - Edge Cases
    
    @Test("Can append empty transcript")
    func appendEmptyTranscript() {
        var conversation = Conversation()
        
        conversation.append(Conversation.Item(
            message: .assistant(""),
            transcript: ""
        ))
        
        let items = Array(conversation)
        #expect(items.count == 1)
        #expect(items[0].transcript == "")
    }
    
    @Test("Can append multiline content")
    func appendMultilineContent() {
        var conversation = Conversation()
        
        let multiline = """
            Line 1
            Line 2
            Line 3
            """
        
        conversation.append(Conversation.Item(
            message: .assistant(multiline),
            transcript: multiline
        ))
        
        let items = Array(conversation)
        #expect(items.count == 1)
        #expect(items[0].transcript == multiline)
    }
    
    @Test("Can append unicode content")
    func appendUnicodeContent() {
        var conversation = Conversation()
        
        let unicode = "Hello 世界 🌍 émojis: 🚀💻🔥"
        
        conversation.append(Conversation.Item(
            message: .user(unicode),
            transcript: unicode
        ))
        
        let items = Array(conversation)
        #expect(items.count == 1)
        #expect(items[0].transcript == unicode)
    }
    
    @Test("Large conversation handling")
    func largeConversationHandling() {
        var conversation = Conversation()
        
        // Add 100 items
        for i in 0..<100 {
            conversation.append(Conversation.Item(
                message: .user("Message \(i)"),
                transcript: "Transcript \(i)"
            ))
        }
        
        let items = Array(conversation)
        #expect(items.count == 100, "Should handle 100 items")
        
        // Verify first and last
        #expect(items[0].transcript == "Transcript 0")
        #expect(items[99].transcript == "Transcript 99")
    }
}
