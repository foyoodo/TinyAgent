import Testing
import Foundation
import TinyAgentOpenAI

@Suite("OpenAI Model Client Tests")
struct OpenAIModelClientTests {

    @Test("Delta textContent returns content when present")
    func deltaTextContentReturnsContent() throws {
        let json = """
        {"content": "Hello", "reasoning_content": null}
        """.data(using: .utf8)!

        let delta = try JSONDecoder().decode(Delta.self, from: json)

        #expect(delta.textContent == "Hello", "textContent should return content field when present")
    }

    @Test("Delta textContent returns reasoningContent when content is null")
    func deltaTextContentReturnsReasoningContent() throws {
        let json = """
        {"content": null, "reasoning_content": "Thinking..."}
        """.data(using: .utf8)!

        let delta = try JSONDecoder().decode(Delta.self, from: json)

        #expect(delta.textContent == "Thinking...", "textContent should return reasoning_content when content is null")
    }

    @Test("Delta textContent returns content over reasoningContent when both present")
    func deltaTextContentPrefersContent() throws {
        let json = """
        {"content": "Final answer", "reasoning_content": "Thinking process"}
        """.data(using: .utf8)!

        let delta = try JSONDecoder().decode(Delta.self, from: json)

        #expect(delta.textContent == "Final answer", "textContent should prefer content over reasoning_content")
    }

    @Test("Delta textContent returns nil when both fields are null")
    func deltaTextContentReturnsNilWhenBothNull() throws {
        let json = """
        {"content": null, "reasoning_content": null}
        """.data(using: .utf8)!

        let delta = try JSONDecoder().decode(Delta.self, from: json)

        #expect(delta.textContent == nil, "textContent should return nil when both fields are null")
    }

    @Test("Parse complete SSE stream with reasoning_content")
    func parseSSEStreamWithReasoningContent() async throws {
        let parser = SSEParser()

        // Simulate SSE stream chunks with reasoning_content (like Moonshot/Kimi API)
        // Note: SSE format requires "data: " (colon + space) prefix and double newlines between events
        let sseStream = "data: {\"id\":\"chatcmpl-123\",\"object\":\"chat.completion.chunk\",\"choices\":[{\"delta\":{\"reasoning_content\":\"Hello\"}}]}\n\ndata: {\"id\":\"chatcmpl-123\",\"object\":\"chat.completion.chunk\",\"choices\":[{\"delta\":{\"reasoning_content\":\" world\"}}]}\n\ndata: {\"id\":\"chatcmpl-123\",\"object\":\"chat.completion.chunk\",\"choices\":[{\"delta\":{\"content\":\"!\"}}]}\n\ndata: [DONE]\n\n"

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
        // Note: SSE format requires "data: " (colon + space) prefix
        let sseStream = "data: {\"id\":\"1\",\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}\n\ndata: {\"id\":\"1\",\"choices\":[{\"delta\":{\"reasoning_content\":\"Let me think\"}}]}\n\ndata: {\"id\":\"1\",\"choices\":[{\"delta\":{\"reasoning_content\":\" about this\"}}]}\n\ndata: {\"id\":\"1\",\"choices\":[{\"delta\":{\"content\":\"Final answer\"}}]}\n\ndata: {\"id\":\"1\",\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"

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

    @Test("ChatCompletionChunk parsing with empty choices")
    func parseChunkWithEmptyChoices() throws {
        // Some APIs send chunks with empty choices for usage info
        let json = """
        {"id":"chatcmpl-123","object":"chat.completion.chunk","choices":[],"usage":{"prompt_tokens":10,"completion_tokens":5}}
        """.data(using: .utf8)!

        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: json)

        #expect(chunk.choices.isEmpty, "Should handle empty choices array")
        #expect(chunk.id == "chatcmpl-123", "Should parse id correctly")
    }

    @Test("Handle finish_reason in delta")
    func parseFinishReason() throws {
        let json = """
        {"id":"chatcmpl-123","choices":[{"delta":{"content":"Done"},"finish_reason":"stop"}]}
        """.data(using: .utf8)!

        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: json)

        #expect(chunk.choices.first?.finishReason == "stop", "Should parse finish_reason correctly")
        #expect(chunk.choices.first?.delta.textContent == "Done", "Should still parse content with finish_reason")
    }
}
