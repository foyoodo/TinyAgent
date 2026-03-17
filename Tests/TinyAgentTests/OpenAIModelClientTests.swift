import Testing
import Foundation
import TinyAgentOpenAI

// MARK: - Test Tags

extension Tag {
    @Tag static var openAI: Self
    @Tag static var parsing: Self
    @Tag static var sse: Self
}

// MARK: - Parameterized Test Data

struct DeltaTestCase {
    let name: String
    let json: String
    let expectedContent: String?
    
    static let allCases: [DeltaTestCase] = [
        DeltaTestCase(
            name: "content only",
            json: #"{"content": "Hello", "reasoning_content": null}"#,
            expectedContent: "Hello"
        ),
        DeltaTestCase(
            name: "reasoning_content only",
            json: #"{"content": null, "reasoning_content": "Thinking..."}"#,
            expectedContent: "Thinking..."
        ),
        DeltaTestCase(
            name: "both fields present",
            json: #"{"content": "Final answer", "reasoning_content": "Thinking process"}"#,
            expectedContent: "Final answer"
        ),
        DeltaTestCase(
            name: "both fields null",
            json: #"{"content": null, "reasoning_content": null}"#,
            expectedContent: nil
        ),
        DeltaTestCase(
            name: "empty content",
            json: #"{"content": "", "reasoning_content": null}"#,
            expectedContent: ""
        ),
    ]
}

// MARK: - Delta Tests

@Suite("Delta Parsing Tests", .tags(.openAI, .parsing))
struct DeltaTests {
    
    @Test("Delta textContent returns expected value",
          arguments: DeltaTestCase.allCases)
    func deltaTextContent(testCase: DeltaTestCase) throws {
        let jsonData = try #require(testCase.json.data(using: .utf8), "Invalid test JSON")
        let delta = try JSONDecoder().decode(Delta.self, from: jsonData)
        
        #expect(
            delta.textContent == testCase.expectedContent,
            "For case '\(testCase.name)', expected '\(String(describing: testCase.expectedContent))' but got '\(String(describing: delta.textContent))'"
        )
    }
}

// MARK: - SSE Parser Tests

@Suite("SSE Parser Tests", .tags(.openAI, .sse))
struct SSEParserTests {
    
    @Test("Parse complete SSE stream with reasoning_content")
    func parseSSEStreamWithReasoningContent() async throws {
        let parser = SSEParser()
        
        // Simulate SSE stream chunks with reasoning_content (like Moonshot/Kimi API)
        // Note: SSE format requires "data: " (colon + space) prefix and double newlines between events
        let sseStream = """
            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","choices":[{"delta":{"reasoning_content":"Hello"}}]}

            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","choices":[{"delta":{"reasoning_content":" world"}}]}

            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","choices":[{"delta":{"content":"!"}}]}

            data: [DONE]

            """
        
        var allContent: String = ""
        
        let events = await parser.parse(sseStream)
        for event in events {
            if event == "[DONE]" { break }
            
            guard let data = event.data(using: .utf8) else { continue }
            let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: data)
            
            if let choice = chunk.choices.first,
               let text = choice.delta.textContent {
                allContent.append(text)
            }
        }
        
        #expect(allContent == "Hello world!", "Should concatenate all content from reasoning_content and content fields")
    }
    
    @Test("Parse SSE stream with mixed delta fields")
    func parseSSEStreamWithMixedFields() async throws {
        let parser = SSEParser()
        
        // Mixed stream with both reasoning_content and content
        let sseStream = """
            data: {"id":"1","choices":[{"delta":{"role":"assistant"}}]}

            data: {"id":"1","choices":[{"delta":{"reasoning_content":"Let me think"}}]}

            data: {"id":"1","choices":[{"delta":{"reasoning_content":" about this"}}]}

            data: {"id":"1","choices":[{"delta":{"content":"Final answer"}}]}

            data: {"id":"1","choices":[{"delta":{},"finish_reason":"stop"}]}

            """
        
        let events = await parser.parse(sseStream)
        var collectedContent: [String] = []
        
        for event in events {
            guard let data = event.data(using: .utf8) else { continue }
            let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: data)
            
            if let choice = chunk.choices.first,
               let text = choice.delta.textContent {
                collectedContent.append(text)
            }
        }
        
        #expect(collectedContent == ["Let me think", " about this", "Final answer"],
                "Should collect content from both reasoning_content and content fields in order")
    }
    
    @Test("Parse empty SSE data")
    func parseEmptySSE() async throws {
        let parser = SSEParser()
        
        let events = await parser.parse("")
        
        #expect(events.isEmpty, "Empty input should produce no events")
    }
    
    @Test("Parse SSE with incomplete data")
    func parseIncompleteSSE() async throws {
        let parser = SSEParser()
        
        // Incomplete data (no double newline)
        let incompleteStream = "data: {\"message\": \"hello\"}"
        let events = await parser.parse(incompleteStream)
        
        // Should buffer incomplete data and not emit events yet
        #expect(events.isEmpty, "Incomplete data should be buffered")
        
        // Complete the event
        let completion = "\n\ndata: [DONE]\n\n"
        let finalEvents = await parser.parse(completion)
        
        #expect(finalEvents.count == 2, "Should emit both buffered and new events")
    }
}

// MARK: - ChatCompletionChunk Tests

@Suite("ChatCompletionChunk Tests", .tags(.openAI, .parsing))
struct ChatCompletionChunkTests {
    
    @Test("Parse chunk with empty choices")
    func parseChunkWithEmptyChoices() throws {
        // Some APIs send chunks with empty choices for usage info
        let json = """
            {"id":"chatcmpl-123","object":"chat.completion.chunk","choices":[],"usage":{"prompt_tokens":10,"completion_tokens":5}}
            """.data(using: .utf8)!
        
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: json)
        
        #expect(chunk.choices.isEmpty, "Should handle empty choices array")
        #expect(chunk.id == "chatcmpl-123", "Should parse id correctly")
    }
    
    @Test("Parse chunk with finish_reason")
    func parseFinishReason() throws {
        let json = """
            {"id":"chatcmpl-123","choices":[{"delta":{"content":"Done"},"finish_reason":"stop"}]}
            """.data(using: .utf8)!
        
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: json)
        
        let choice = try #require(chunk.choices.first, "Should have at least one choice")
        #expect(choice.finishReason == "stop", "Should parse finish_reason correctly")
        #expect(choice.delta.textContent == "Done", "Should still parse content with finish_reason")
    }
    
    @Test("Parse chunk with tool calls")
    func parseChunkWithToolCalls() throws {
        let json = """
            {"id":"chatcmpl-123","choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_123","type":"function","function":{"name":"shell","arguments":"{}"}}]}}]}
            """.data(using: .utf8)!
        
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: json)
        
        let choice = try #require(chunk.choices.first, "Should have at least one choice")
        let toolCalls = try #require(choice.delta.toolCalls, "Should have tool_calls")
        let firstToolCall = try #require(toolCalls.first, "Should have at least one tool call")
        
        #expect(firstToolCall.index == 0)
        #expect(firstToolCall.id == "call_123")
        #expect(firstToolCall.type == "function")
        #expect(firstToolCall.function?.name == "shell")
    }
    
    @Test("Parse multiple chunks in sequence")
    func parseMultipleChunks() throws {
        let chunks = [
            #"{"id":"1","choices":[{"delta":{"content":"Hello"}}]}"#,
            #"{"id":"2","choices":[{"delta":{"content":" "}}]}"#,
            #"{"id":"3","choices":[{"delta":{"content":"World"}}]}"#,
        ]
        
        var allContent: [String] = []
        
        for chunkJson in chunks {
            let data = chunkJson.data(using: .utf8)!
            let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: data)
            
            if let text = chunk.choices.first?.delta.textContent {
                allContent.append(text)
            }
        }
        
        #expect(allContent == ["Hello", " ", "World"])
    }
}
