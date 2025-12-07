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
        let formattedPrompt = """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>

        \(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>

        \(input)<|eot_id|><|start_header_id|>assistant<|end_header_id|>

        """
        
        // Get response
        await llm.respond(to: formattedPrompt)
        
        // Clean and return output
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
