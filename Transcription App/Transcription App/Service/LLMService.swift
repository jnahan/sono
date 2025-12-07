import Foundation
import LLM

/// Service for LLM interactions using Llama 3.2 1B Instruct model
class LLMService {
    // MARK: - Singleton
    static let shared = LLMService()
    
    // MARK: - Properties
    private var llm: LLM?
    
    // MARK: - Configuration
    private let modelName = "Llama-3.2-1B-Instruct-Q4_K_M"
    
    // MARK: - Initialization
    private init() {
        // Preload the model in the background
        Task {
            await preloadModel()
        }
    }

    // MARK: - Public Methods

    /// Preloads the LLM model to reduce first-use latency
    @MainActor
    func preloadModel() async {
        // Check if model exists in bundle
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "gguf") else {
            return
        }

        // Initialize LLM to ensure it's ready
        if llm == nil {
            llm = LLM(from: modelURL)
        }
    }
    
    /// Gets a completion from the LLM
    /// - Parameters:
    ///   - input: The user's input prompt
    ///   - systemPrompt: The system prompt defining the assistant's behavior
    /// - Returns: The LLM's response
    @MainActor
    func getCompletion(from input: String, systemPrompt: String = "You are a helpful assistant.") async throws -> String {
        // Always reset to ensure clean state and avoid KV cache corruption
        llm = nil
        
        // Load model
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "gguf") else {
            throw LLMError.modelNotLoaded
        }
        
        // Initialize LLM without template (we'll format manually)
        llm = LLM(from: modelURL)
        
        guard let llm = llm else {
            throw LLMError.modelNotLoaded
        }
        
        // Manually format the prompt for Llama 3.2 chat template
        // Note: BOS token (<|begin_of_text|>) is added automatically by the LLM library
        let formattedPrompt = """
        <|start_header_id|>system<|end_header_id|>

        \(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>

        \(input)<|eot_id|><|start_header_id|>assistant<|end_header_id|>

        """
        
        // Get response
        await llm.respond(to: formattedPrompt)
        
        // Clean and return output
        return llm.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Gets a streaming completion from the LLM, yielding text chunks as they're generated
    /// Uses the LLM library's built-in update closure for streaming
    /// - Parameters:
    ///   - input: The user's input prompt
    ///   - systemPrompt: The system prompt defining the assistant's behavior
    ///   - onChunk: Callback called with each new chunk of text as it's generated
    /// - Returns: The complete LLM's response
    @MainActor
    func getStreamingCompletion(
        from input: String,
        systemPrompt: String = "You are a helpful assistant.",
        onChunk: @escaping (String) -> Void
    ) async throws -> String {
        // Always reset to ensure clean state and avoid KV cache corruption
        llm = nil
        
        // Load model
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "gguf") else {
            throw LLMError.modelNotLoaded
        }
        
        // Initialize LLM without template (we'll format manually)
        llm = LLM(from: modelURL)
        
        guard let llm = llm else {
            throw LLMError.modelNotLoaded
        }
        
        // Manually format the prompt for Llama 3.2 chat template
        let formattedPrompt = """
        <|start_header_id|>system<|end_header_id|>

        \(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>

        \(input)<|eot_id|><|start_header_id|>assistant<|end_header_id|>

        """
        
        // Set up the update closure to receive streaming chunks
        // The update closure is called during respond() with each chunk
        llm.update = { outputDelta in
            if let delta = outputDelta {
                // Stream the chunk on main thread
                Task { @MainActor in
                    onChunk(delta)
                }
            }
            // nil outputDelta indicates the stream is complete
        }
        
        // Generate the response - update closure will be called during this
        await llm.respond(to: formattedPrompt)
        
        // Clear the update closure after use to avoid it being called in subsequent requests
        llm.update = { _ in }
        
        // Return the complete output
        return llm.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors
enum LLMError: LocalizedError {
    case modelNotLoaded
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "LLM model is not loaded."
        }
    }
}
