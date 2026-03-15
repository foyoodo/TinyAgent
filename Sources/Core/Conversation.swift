import Foundation

/// Conversation management
public struct Conversation: Sendable {
    private var items: [Item] = []

    public init() {}
    
    public mutating func append(_ item: Item) {
        items.append(item)
    }
}

extension Conversation: Sequence {
    public func makeIterator() -> IndexingIterator<[Item]> {
        items.makeIterator()
    }
}

extension Conversation {
    public struct Item: Sendable {
        public let message: ModelMessage
        public let transcript: String

        public init(message: ModelMessage, transcript: String) {
            self.message = message
            self.transcript = transcript
        }
    }
}
