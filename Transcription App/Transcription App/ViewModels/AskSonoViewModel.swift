//
//  AskSonoViewModel.swift
//  Transcription App
//
//  Created by Claude on 12/8/25.
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

    // MARK: - Private Properties

    private let recording: Recording

    // MARK: - Initialization

    init(recording: Recording) {
        self.recording = recording
    }

    // MARK: - Public Methods

    /// Sends the user's prompt to the LLM with transcription context
    func sendPrompt() async {
        let promptText = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptText.isEmpty else { return }

        guard !recording.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Cannot answer questions: transcription is empty."
            return
        }

        // Add user message to chat
        let userMessage = ChatMessage(text: promptText, isUser: true)
        messages.append(userMessage)

        // Clear input
        userPrompt = ""

        isProcessing = true
        error = nil

        do {
            // Check if transcription exceeds max context length
            if recording.fullText.count > AppConstants.LLM.maxContextLength {
                let aiMessage = ChatMessage(text: "Failed to summarize recording", isUser: false)
                messages.append(aiMessage)
                isProcessing = false
                return
            }

            // Build prompt
            let prompt = """
            Transcription:
            \(recording.fullText)

            Question: \(promptText)
            """

            // Create placeholder message for streaming
            let streamingId = UUID()
            streamingMessageId = streamingId
            streamingText = ""
            let placeholderMessage = ChatMessage(id: streamingId, text: "", isUser: false)
            messages.append(placeholderMessage)

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
                isProcessing = false
                removeLastMessage()
                return
            }

            // Finalize the message
            finalizeStreamingMessage(with: trimmedResponse)

            // Clear streaming state
            streamingMessageId = nil
            streamingText = ""

        } catch {
            self.error = "Failed to get response: \(error.localizedDescription)"
            removeLastMessage()
            streamingText = ""
            streamingMessageId = nil
        }

        isProcessing = false
    }

    /// Resends the last user message
    func resendLastMessage() {
        // Find last user message
        guard let lastUserMessage = messages.last(where: { $0.isUser }) else {
            return
        }

        // Set it as current prompt and send
        userPrompt = lastUserMessage.text
        Task {
            await sendPrompt()
        }
    }

    // MARK: - Private Methods

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
