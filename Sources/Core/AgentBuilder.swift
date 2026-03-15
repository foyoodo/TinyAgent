import Foundation

/// Agent builder
public struct AgentBuilder {
    private var modelClient: ModelClient?
    private var tools: [any Tool] = []
    private var systemPrompt: String?
    
    public init() {}
    
    public mutating func withModelClient(_ client: ModelClient) {
        self.modelClient = client
    }
    
    public mutating func withTool(_ tool: some Tool) {
        tools.append(tool)
    }
    
    public mutating func withSystemPrompt(_ prompt: String) {
        self.systemPrompt = prompt
    }
    
    public func build() async -> Agent {
        guard let client = modelClient else {
            fatalError("ModelClient is required")
        }
        
        let toolManager = ToolManager()
        for tool in tools {
            await toolManager.register(tool)
        }
        
        return Agent(
            modelClient: client,
            toolManager: toolManager,
            systemPrompt: systemPrompt
        )
    }
}
