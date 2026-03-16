import Foundation

/// SSE event parser
public actor SSEParser {
    private var buffer: String = ""

    public init() {}

    public func parse(_ data: String) -> [String] {
        buffer.append(data)
        var events: [String] = []

        while let doubleNewline = buffer.range(of: "\n\n") {
            let event = String(buffer[..<doubleNewline.lowerBound])
            // Remove the processed event including the double newline
            let removeEnd = doubleNewline.upperBound
            if removeEnd < buffer.endIndex {
                buffer.removeSubrange(buffer.startIndex..<removeEnd)
            } else {
                buffer.removeAll()
            }

            // Parse field line: "data: {...}"
            if let colonRange = event.range(of: ": ") {
                let field = String(event[..<colonRange.lowerBound])
                let value = String(event[colonRange.upperBound...])

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
        if let colonRange = remaining.range(of: ": ") {
            let field = String(remaining[..<colonRange.lowerBound])
            let value = String(remaining[colonRange.upperBound...])

            if field == "data" {
                return [value]
            }
        }

        return []
    }
}
