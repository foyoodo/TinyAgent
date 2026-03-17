import Foundation

/// SSE event parser
public actor SSEParser {
    private var buffer: String = ""

    public init() {}

    public func parse(_ data: String) -> [String] {
        buffer.append(data)
        var events: [String] = []

        while let newline = buffer.range(of: "\n") {
            let event = String(buffer[..<newline.lowerBound])
            // Remove the processed event including the double newline
            let removeEnd = newline.upperBound
            if removeEnd < buffer.endIndex {
                buffer.removeSubrange(buffer.startIndex..<removeEnd)
            } else {
                buffer.removeAll()
            }

            // Parse field line: "data: {...}" or "data:{...}"
            if let colonIndex = event.firstIndex(of: ":") {
                let field = String(event[..<colonIndex])
                var value = String(event[event.index(after: colonIndex)...])
                // Strip optional leading space after colon
                if value.first == " " {
                    value.removeFirst()
                }

                if field == "data" {
                    events.append(value)
                }
            }
        }

        return events
    }

    public func flush() -> [String] {
        let remaining = buffer
        buffer = ""

        guard !remaining.isEmpty else { return [] }

        // Try to parse any remaining data
        if let colonIndex = remaining.firstIndex(of: ":") {
            let field = String(remaining[..<colonIndex])
            var value = String(remaining[remaining.index(after: colonIndex)...])
            // Strip optional leading space after colon
            if value.first == " " {
                value.removeFirst()
            }

            if field == "data" {
                return [value]
            }
        }

        return []
    }
}
