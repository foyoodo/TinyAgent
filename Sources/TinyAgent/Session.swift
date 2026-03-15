import Foundation
@_exported import TinyAgentCore

/// Session builder
public struct SessionBuilder {
    private var agentBuilder = AgentBuilder()
    
    public init() {}
    
    public mutating func withModelClient(_ client: ModelClient) {
        agentBuilder.withModelClient(client)
    }
    
    public mutating func withSystemPrompt(_ prompt: String) {
        agentBuilder.withSystemPrompt(prompt)
    }
    
    public mutating func build() async -> Session {
        agentBuilder.withTool(ShellTool())
        agentBuilder.withTool(GlobTool())
        agentBuilder.withTool(ReadFileTool())
        
        let agent = await agentBuilder.build()
        return Session(agent: agent)
    }
}

/// Session
public actor Session {
    private let agent: Agent
    
    internal init(agent: Agent) {
        self.agent = agent
    }
    
    /// Event stream
    public var events: AsyncStream<AgentEvent> {
        get async {
            await agent.events
        }
    }
    
    public func sendMessage(_ message: String) async {
        await agent.enqueueUserInput(message)
    }
}
