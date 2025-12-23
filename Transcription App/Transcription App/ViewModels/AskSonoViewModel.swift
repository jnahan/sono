//
//  AskSonoViewModel.swift
//  Transcription App
//

import Foundation
import SwiftUI

/// ViewModel for Ask Sono chat interface
@MainActor
class AskSonoViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var userPrompt: String = ""
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing: Bool = false
    @Published var error: String?
    @Published var streamingMessageId: UUID? = nil
    @Published var streamingText: String = ""
    @Published var chunkProgress: String = "" // e.g., "Processing chunk 2 of 5..."
    @Published private(set) var inputFieldId: Int = 0

    // MARK: - Private Properties

    private let recording: Recording

    // MARK: - Initialization

    init(recording: Recording) {
        self.recording = recording
    }

    // MARK: - Private Helper Methods

    /// Splits text into chunks at natural boundaries (sentences/paragraphs)
    /// - Parameters:
    ///   - text: The text to split
    ///   - maxChunkSize: Maximum size of each chunk in characters
    /// - Returns: Array of text chunks
    private func splitIntoChunks(_ text: String, maxChunkSize: Int) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""

        // Split by sentences (periods followed by space or newline)
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))

        for sentence in sentences {
            let trimmedSentence = sentence.trimmingCharacters(in: .whitespaces)
            if trimmedSentence.isEmpty { continue }

            let sentenceWithPunctuation = trimmedSentence + "."

            // If adding this sentence would exceed max size, save current chunk and start new one
            if currentChunk.count + sentenceWithPunctuation.count > maxChunkSize && !currentChunk.isEmpty {
                chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                currentChunk = sentenceWithPunctuation + " "
            } else {
                currentChunk += sentenceWithPunctuation + " "
            }
        }

        // Add remaining chunk if not empty
        if !currentChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Fallback: If we still have a chunk that's too large (single sentence > maxChunkSize),
        // split it by character count
        var finalChunks: [String] = []
        for chunk in chunks {
            if chunk.count <= maxChunkSize {
                finalChunks.append(chunk)
            } else {
                // Split oversized chunk into smaller pieces
                var remaining = chunk
                while !remaining.isEmpty {
                    let endIndex = remaining.index(remaining.startIndex, offsetBy: min(maxChunkSize, remaining.count))
                    let piece = String(remaining[..<endIndex])
                    finalChunks.append(piece)
                    remaining = String(remaining[endIndex...])
                }
            }
        }

        return finalChunks
    }

    // MARK: - Public Methods

    /// Sends the user's prompt to the LLM with transcription context
    func sendPrompt() async {
        let promptText = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptText.isEmpty else { return }

        // Clear input immediately and force TextField to rebuild
        userPrompt = ""
        inputFieldId += 1

        await sendPromptWithText(promptText)
    }

    /// Resends the last user message
    func resendLastMessage() {
        // Find last user message
        guard let lastUserMessage = messages.last(where: { $0.isUser }) else {
            return
        }

        // Send the message directly without setting userPrompt
        Task {
            await sendPromptWithText(lastUserMessage.text)
        }
    }

    // MARK: - Private Methods

    /// Internal method to send a prompt with specific text
    private func sendPromptWithText(_ promptText: String) async {
        let trimmedText = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        guard !recording.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Cannot answer questions: transcription is empty."
            return
        }

        // Add user message to chat
        let userMessage = ChatMessage(text: trimmedText, isUser: true)
        messages.append(userMessage)

        isProcessing = true
        error = nil
        chunkProgress = ""

        do {
            // Create placeholder message for streaming
            let streamingId = UUID()
            streamingMessageId = streamingId
            streamingText = ""
            let placeholderMessage = ChatMessage(id: streamingId, text: "", isUser: false)
            messages.append(placeholderMessage)

            // Check if we need chunked processing
            if recording.fullText.count > AppConstants.LLM.maxInputCharacters {
                Logger.info("AskSonoViewModel", "Using chunked processing for \(recording.fullText.count) characters")
                try await processChunkedQuestion(question: trimmedText, streamingId: streamingId)
            } else {
                Logger.info("AskSonoViewModel", "Using standard processing for \(recording.fullText.count) characters")
                try await processStandardQuestion(question: trimmedText, streamingId: streamingId)
            }

        } catch {
            self.error = "Failed to get response: \(error.localizedDescription)"
            removeLastMessage()
            streamingText = ""
            streamingMessageId = nil
            chunkProgress = ""
        }

        isProcessing = false
    }

    /// Standard Q&A for shorter transcriptions
    private func processStandardQuestion(question: String, streamingId: UUID) async throws {
        // Build prompt
        let prompt = """
        Transcription:
        \(recording.fullText)

        Question: \(question)
        """

        // Stream the response
        let llmResponse = try await LLMService.shared.getStreamingCompletion(
            from: prompt,
            systemPrompt: LLMPrompts.transcriptionQA
        ) { [weak self] chunk in
            guard let self = self else { return }
            Task { @MainActor in
                if self.streamingMessageId == streamingId {
                    self.streamingText += chunk
                    self.updateStreamingMessage()
                }
            }
        }

        // Validate and finalize response
        let trimmedResponse = llmResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard LLMResponseValidator.isValid(trimmedResponse) else {
            error = "Model returned invalid response. Please try again."
            removeLastMessage()
            return
        }

        // Finalize the message
        finalizeStreamingMessage(with: trimmedResponse)

        // Clear streaming state
        streamingMessageId = nil
        streamingText = ""
    }

    /// Chunked Q&A for longer transcriptions using Map-Reduce pattern
    private func processChunkedQuestion(question: String, streamingId: UUID) async throws {
        // Maximum chunk size - leave room for prompts
        let maxChunkSize = 12000

        // Step 1: Split text into chunks
        let chunks = splitIntoChunks(recording.fullText, maxChunkSize: maxChunkSize)
        Logger.info("AskSonoViewModel", "Split into \(chunks.count) chunks")

        // Step 2: Ask question for each chunk (Map phase)
        var chunkAnswers: [String] = []

        for (index, chunk) in chunks.enumerated() {
            // Update progress
            chunkProgress = "Searching part \(index + 1) of \(chunks.count)..."
            Logger.info("AskSonoViewModel", "Processing chunk \(index + 1)/\(chunks.count), size: \(chunk.count) chars")

            // Reset streaming for this chunk
            streamingText = ""

            let chunkPrompt: String
            if chunks.count == 1 {
                // Only one chunk (shouldn't happen, but handle gracefully)
                chunkPrompt = """
                Transcription:
                \(chunk)

                Question: \(question)
                """
            } else {
                // Multiple chunks - provide context
                chunkPrompt = """
                This is part \(index + 1) of \(chunks.count) from a longer transcription.

                Transcription excerpt:
                \(chunk)

                Question: \(question)

                Please answer based on this section. If the answer is not in this section, say "Not found in this section."
                """
            }

            let chunkAnswer = try await LLMService.shared.getStreamingCompletion(
                from: chunkPrompt,
                systemPrompt: LLMPrompts.transcriptionQA
            ) { [weak self] streamChunk in
                guard let self = self else { return }
                Task { @MainActor in
                    if self.streamingMessageId == streamingId {
                        self.streamingText += streamChunk
                        self.updateStreamingMessage()
                    }
                }
            }

            // Validate chunk answer
            guard LLMResponseValidator.isValid(chunkAnswer) else {
                throw NSError(domain: "AskSonoViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response for chunk \(index + 1)"])
            }

            chunkAnswers.append(chunkAnswer.trimmingCharacters(in: .whitespacesAndNewlines))
            Logger.info("AskSonoViewModel", "Chunk \(index + 1) answer: \(chunkAnswer.count) chars")
        }

        // Step 3: Combine chunk answers
        let combinedAnswers = chunkAnswers.joined(separator: "\n\n---\n\n")
        Logger.info("AskSonoViewModel", "Combined answers: \(combinedAnswers.count) chars")

        // Step 4: Generate final answer from chunk answers (Reduce phase)
        chunkProgress = "Creating final answer..."
        streamingText = ""

        let finalPrompt = """
        The following are answers from different sections of a transcription to the question: "\(question)"

        Answers from sections:
        \(combinedAnswers)

        Please create a single comprehensive answer that combines all relevant information. If all sections say the information was not found, say that the answer is not in the transcription.
        """

        let finalAnswer = try await LLMService.shared.getStreamingCompletion(
            from: finalPrompt,
            systemPrompt: LLMPrompts.transcriptionQA
        ) { [weak self] chunk in
            guard let self = self else { return }
            Task { @MainActor in
                if self.streamingMessageId == streamingId {
                    self.streamingText += chunk
                    self.updateStreamingMessage()
                }
            }
        }

        // Validate final answer
        let trimmedResponse = finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard LLMResponseValidator.isValid(trimmedResponse) else {
            error = "Model returned invalid response. Please try again."
            removeLastMessage()
            return
        }

        // Finalize the message
        finalizeStreamingMessage(with: trimmedResponse)

        // Clear UI state
        streamingMessageId = nil
        streamingText = ""
        chunkProgress = ""

        Logger.info("AskSonoViewModel", "Final answer saved: \(trimmedResponse.count) chars")
    }

    private func updateStreamingMessage() {
        if let lastIndex = messages.indices.last, !messages[lastIndex].isUser {
            let existingMessage = messages[lastIndex]
            let updatedMessage = ChatMessage(
                id: existingMessage.id,
                text: streamingText,
                isUser: false,
                timestamp: existingMessage.timestamp
            )
            messages[lastIndex] = updatedMessage
        }
    }

    private func finalizeStreamingMessage(with text: String) {
        if let lastIndex = messages.indices.last, !messages[lastIndex].isUser {
            let existingMessage = messages[lastIndex]
            let finalMessage = ChatMessage(
                id: existingMessage.id,
                text: text,
                isUser: false,
                timestamp: existingMessage.timestamp
            )
            messages[lastIndex] = finalMessage
        }
    }

    private func removeLastMessage() {
        if !messages.isEmpty && !messages[messages.count - 1].isUser {
            messages.removeLast()
        }
    }
}
