//
//  AskSonoViewModel.swift
//  Transcription App
//

import Foundation
import SwiftUI

@MainActor
final class AskSonoViewModel: ObservableObject {

    // MARK: - Published

    @Published var userPrompt: String = ""
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing: Bool = false
    @Published var error: String?

    @Published var streamingMessageId: UUID? = nil
    @Published var streamingText: String = ""
    @Published var chunkProgress: String = ""
    @Published private(set) var inputFieldId: Int = 0

    // MARK: - Private

    private let recording: Recording

    init(recording: Recording) {
        self.recording = recording
    }

    // MARK: - Public

    /// Keep this async API if your existing UI already calls it.
    func sendPrompt() async {
        let promptText = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptText.isEmpty else { return }
        guard !isProcessing else { return }

        // Clear input immediately and force TextField rebuild (your current behavior)
        userPrompt = ""
        inputFieldId += 1

        await sendPromptWithText(promptText)
    }

    /// Non-async helper (optional): safe to call from Buttons without changing styling.
    func sendPromptFromUI() {
        Task { await self.sendPrompt() }
    }

    func resendLastMessage() {
        guard let lastUserMessage = messages.last(where: { $0.isUser }) else { return }
        Task { await sendPromptWithText(lastUserMessage.text) }
    }

    // MARK: - Core send (FIXED)

    private func sendPromptWithText(_ promptText: String) async {
        let trimmedText = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        // ✅ Always show the user message immediately (prevents “clears but nothing happens”)
        messages.append(ChatMessage(text: trimmedText, isUser: true))

        // ✅ If transcription empty: show assistant message instead of silently returning
        let transcription = recording.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcription.isEmpty else {
            let msg = "I can’t answer yet because this recording doesn’t have a transcription."
            messages.append(ChatMessage(text: msg, isUser: false))
            error = msg
            isProcessing = false
            streamingMessageId = nil
            streamingText = ""
            chunkProgress = ""
            return
        }

        isProcessing = true
        error = nil
        chunkProgress = ""

        do {
            // Placeholder message for streaming
            let streamingId = UUID()
            streamingMessageId = streamingId
            streamingText = ""
            messages.append(ChatMessage(id: streamingId, text: "", isUser: false))

            if transcription.count > AppConstants.LLM.maxInputCharacters {
                Logger.info("AskSonoViewModel", "Using chunked processing for \(transcription.count) characters")
                try await processChunkedQuestion(question: trimmedText, transcription: transcription, streamingId: streamingId)
            } else {
                Logger.info("AskSonoViewModel", "Using standard processing for \(transcription.count) characters")
                try await processStandardQuestion(question: trimmedText, transcription: transcription, streamingId: streamingId)
            }
        } catch {
            self.error = "Failed to get response: \(error.localizedDescription)"
            removeLastMessageIfAssistant()
            streamingText = ""
            streamingMessageId = nil
            chunkProgress = ""
        }

        isProcessing = false
    }

    // MARK: - Standard Q&A

    private func processStandardQuestion(question: String, transcription: String, streamingId: UUID) async throws {
        let prompt = """
        Transcription:
        \(transcription)

        Question: \(question)
        """

        let llmResponse = try await LLMService.shared.getStreamingCompletion(
            from: prompt,
            systemPrompt: LLMPrompts.transcriptionQA
        ) { [weak self] chunk in
            guard let self else { return }
            Task { @MainActor in
                guard self.streamingMessageId == streamingId else { return }
                self.streamingText += chunk
                self.updateStreamingMessage()
            }
        }

        let trimmedResponse = llmResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard LLMResponseValidator.isValid(trimmedResponse) else {
            error = "Model returned invalid response. Please try again."
            removeLastMessageIfAssistant()
            return
        }

        finalizeStreamingMessage(with: trimmedResponse)
        streamingMessageId = nil
        streamingText = ""
    }

    // MARK: - Chunked Q&A (Map-Reduce)

    private func processChunkedQuestion(question: String, transcription: String, streamingId: UUID) async throws {
        let maxChunkSize = 12000
        let chunks = splitIntoChunks(transcription, maxChunkSize: maxChunkSize)
        Logger.info("AskSonoViewModel", "Split into \(chunks.count) chunks")

        var chunkAnswers: [String] = []

        for (index, chunk) in chunks.enumerated() {
            chunkProgress = "Searching part \(index + 1) of \(chunks.count)..."
            streamingText = ""

            let chunkPrompt: String
            if chunks.count == 1 {
                chunkPrompt = """
                Transcription:
                \(chunk)

                Question: \(question)
                """
            } else {
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
                guard let self else { return }
                Task { @MainActor in
                    guard self.streamingMessageId == streamingId else { return }
                    self.streamingText += streamChunk
                    self.updateStreamingMessage()
                }
            }

            guard LLMResponseValidator.isValid(chunkAnswer) else {
                throw NSError(domain: "AskSonoViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response for chunk \(index + 1)"])
            }

            chunkAnswers.append(chunkAnswer.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        chunkProgress = "Creating final answer..."
        streamingText = ""

        let combinedAnswers = chunkAnswers.joined(separator: "\n\n---\n\n")
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
            guard let self else { return }
            Task { @MainActor in
                guard self.streamingMessageId == streamingId else { return }
                self.streamingText += chunk
                self.updateStreamingMessage()
            }
        }

        let trimmedResponse = finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard LLMResponseValidator.isValid(trimmedResponse) else {
            error = "Model returned invalid response. Please try again."
            removeLastMessageIfAssistant()
            return
        }

        finalizeStreamingMessage(with: trimmedResponse)
        streamingMessageId = nil
        streamingText = ""
        chunkProgress = ""
    }

    // MARK: - Streaming message updates

    private func updateStreamingMessage() {
        guard let lastIndex = messages.indices.last else { return }
        guard !messages[lastIndex].isUser else { return }

        let existing = messages[lastIndex]
        messages[lastIndex] = ChatMessage(
            id: existing.id,
            text: streamingText,
            isUser: false,
            timestamp: existing.timestamp
        )
    }

    private func finalizeStreamingMessage(with text: String) {
        guard let lastIndex = messages.indices.last else { return }
        guard !messages[lastIndex].isUser else { return }

        let existing = messages[lastIndex]
        messages[lastIndex] = ChatMessage(
            id: existing.id,
            text: text,
            isUser: false,
            timestamp: existing.timestamp
        )
    }

    private func removeLastMessageIfAssistant() {
        guard let last = messages.last, !last.isUser else { return }
        messages.removeLast()
    }

    // MARK: - Chunking helper

    private func splitIntoChunks(_ text: String, maxChunkSize: Int) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""

        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))

        for sentence in sentences {
            let trimmedSentence = sentence.trimmingCharacters(in: .whitespaces)
            if trimmedSentence.isEmpty { continue }

            let sentenceWithPunctuation = trimmedSentence + "."

            if currentChunk.count + sentenceWithPunctuation.count > maxChunkSize && !currentChunk.isEmpty {
                chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                currentChunk = sentenceWithPunctuation + " "
            } else {
                currentChunk += sentenceWithPunctuation + " "
            }
        }

        if !currentChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        var finalChunks: [String] = []
        for chunk in chunks {
            if chunk.count <= maxChunkSize {
                finalChunks.append(chunk)
            } else {
                var remaining = chunk
                while !remaining.isEmpty {
                    let endIndex = remaining.index(remaining.startIndex, offsetBy: min(maxChunkSize, remaining.count))
                    finalChunks.append(String(remaining[..<endIndex]))
                    remaining = String(remaining[endIndex...])
                }
            }
        }

        return finalChunks
    }
}
