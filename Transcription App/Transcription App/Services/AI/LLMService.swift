import Foundation
import LLM

/// Service for LLM interactions using Llama 3.2 1B Instruct model
class LLMService {
    // MARK: - Singleton
    static let shared = LLMService()
    
    // MARK: - Properties
    private var llm: LLM?
    
    // MARK: - Configuration
    private let modelName = "Llama-3.2-1B-Instruct-Q5_K_M"
    
    // MARK: - Initialization
    private init() {
        // LLM is created fresh for each request to avoid KV cache corruption
        // No preload needed - model loads quickly enough on first use
    }

    // MARK: - Public Methods

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
        systemPrompt: String = LLMPrompts.defaultAssistant,
        onChunk: @escaping (String) -> Void
    ) async throws -> String {
        // Get model URL
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "gguf") else {
            throw LLMError.modelNotLoaded
        }

        // Create a fresh LLM instance for each request to avoid state issues
        // The LLM library may have internal state that needs to be reset
        // All LLM operations MUST run on main thread for Metal/GPU access on physical devices
        // Configure with parameters optimized for quality (matching Enclave defaults)
        let llm = LLM(
            from: modelURL,
            stopSequence: "<|eot_id|>",   // Llama 3.2 end-of-turn token
            topK: 80,                      // Higher top-K for better quality (was 40)
            topP: 0.95,                    // Higher nucleus sampling (was 0.9)
            temp: 0.8,                     // Balanced temperature for quality
            maxTokenCount: AppConstants.LLM.maxTokenCount
        )

        guard let llm = llm else {
            throw LLMError.modelNotLoaded
        }

        Logger.info("LLMService", "LLM created with temp=0.8, topP=0.95, topK=80, maxTokenCount: \(AppConstants.LLM.maxTokenCount)")

        // Manually format the prompt for Llama 3.2 chat template
        // Format: system message, then user message, then assistant response
        // Note: No trailing newline after assistant header - model starts generating immediately
        let formattedPrompt = """
        <|start_header_id|>system<|end_header_id|>

        \(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>

        \(input)<|eot_id|><|start_header_id|>assistant<|end_header_id|>

        """

        // Estimate token count (rough: 1 token ≈ 4 characters for English)
        let estimatedTokens = formattedPrompt.count / 4
        let maxTokens = Int(AppConstants.LLM.maxTokenCount)

        Logger.info("LLMService", "Input length: \(input.count)")
        Logger.info("LLMService", "System prompt length: \(systemPrompt.count)")
        Logger.info("LLMService", "Formatted prompt length: \(formattedPrompt.count)")
        Logger.info("LLMService", "Estimated tokens: ~\(estimatedTokens) (max: \(maxTokens))")
        Logger.info("LLMService", "Input preview: \(input.prefix(200))...")
        Logger.info("LLMService", "Formatted prompt preview: \(formattedPrompt.prefix(300))...")
        Logger.info("LLMService", "Formatted prompt ends with: ...\(formattedPrompt.suffix(100))")

        // Throw error if prompt is too long
        if estimatedTokens > maxTokens - 500 {
            Logger.error("LLMService", "Prompt exceeds context window: ~\(estimatedTokens) tokens (max: \(maxTokens))")
            throw LLMError.inputTooLong
        }

        // Set up the update closure to receive streaming chunks
        // The update closure is called during respond() with each chunk
        // Already on main thread, so onChunk can be called directly
        llm.update = { (outputDelta: String?) in
            if let delta = outputDelta {
                Logger.info("LLMService", "Received chunk: '\(delta.prefix(50))...'")
                onChunk(delta)
            } else {
                Logger.info("LLMService", "Stream complete")
            }
        }

        // Generate the response - guaranteed on main thread via @MainActor
        // This is critical for Metal/GPU access on physical devices
        Logger.info("LLMService", "Starting generation...")
        await llm.respond(to: formattedPrompt)
        Logger.info("LLMService", "Generation finished")

        // Clear the update closure after use
        llm.update = { (_: String?) in }

        // Get the output and clean it up
        let rawOutput = llm.output

        // Remove any leading/trailing whitespace and newlines
        let cleanedOutput = rawOutput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        // Log for debugging
        Logger.info("LLMService", "Raw output length: \(rawOutput.count), cleaned length: \(cleanedOutput.count)")
        if cleanedOutput.isEmpty {
            Logger.warning("LLMService", "Output is empty after trimming. Raw output was: '\(rawOutput)'")
        } else if cleanedOutput == "..." {
            Logger.warning("LLMService", "LLM returned '...' indicating empty generation. This suggests the model failed to generate tokens.")
        } else {
            Logger.success("LLMService", "Generated response: '\(cleanedOutput.prefix(100))...'")
        }

        return cleanedOutput
    }
}

// MARK: - Errors
enum LLMError: LocalizedError {
    case modelNotLoaded
    case inputTooLong

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "LLM model is not loaded."
        case .inputTooLong:
            return "Transcription is too long to process. Maximum length is approximately \(AppConstants.LLM.maxInputCharacters) characters."
        }
    }
}
