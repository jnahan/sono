//
//  SummaryService.swift
//  Transcription App
//
//  Created by Claude on 12/15/25.
//

import Foundation
import SwiftData

/// Service for generating AI summaries of transcriptions
/// Centralizes summary generation logic used across ViewModels
final class SummaryService {

    // MARK: - Singleton

    static let shared = SummaryService()

    private init() {}

    // MARK: - Public Methods

    /// Generates a summary for a recording's transcription
    /// - Parameters:
    ///   - recording: The recording to generate a summary for
    ///   - modelContext: The SwiftData model context to save changes
    ///   - onStreamingChunk: Optional callback for streaming text chunks
    ///   - onComplete: Callback with result (nil = success, error message = failure)
    /// - Returns: Tuple of (streamingSummary: String, error: String?)
    @MainActor
    func generateSummary(
        for recording: Recording,
        modelContext: ModelContext,
        onStreamingChunk: @escaping (String) -> Void
    ) async -> (streamingSummary: String, error: String?) {

        // Validate transcription exists
        guard !recording.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ("", ErrorMessages.Summary.emptyTranscription)
        }

        // Check if transcription exceeds max context length
        if recording.fullText.count > AppConstants.LLM.maxContextLength {
            recording.summary = "Failed to summarize recording"

            // Save the failure message
            do {
                try modelContext.save()
            } catch {
                Logger.error("SummaryService", "Failed to save context length error: \(error.localizedDescription)")
            }

            return ("", "Transcription exceeds maximum context length (\(AppConstants.LLM.maxContextLength) characters)")
        }

        let prompt = recording.fullText
        var streamingSummary = ""

        do {
            // Stream the response
            let summary = try await LLMService.shared.getStreamingCompletion(
                from: prompt,
                systemPrompt: LLMPrompts.summarization
            ) { chunk in
                Task { @MainActor in
                    streamingSummary += chunk
                    onStreamingChunk(chunk)
                }
            }

            // Validate response
            guard LLMResponseValidator.isValid(summary) else {
                Logger.warning("SummaryService", "LLM returned invalid response")
                return ("", ErrorMessages.Summary.invalidResponse)
            }

            // Limit summary length
            let finalSummary = LLMResponseValidator.limit(
                summary,
                to: AppConstants.LLM.maxSummaryLength
            )

            recording.summary = finalSummary

            // Save asynchronously to avoid blocking main thread
            do {
                try modelContext.save()
                Logger.success("SummaryService", "Summary generated and saved (\(finalSummary.count) chars)")
            } catch {
                Logger.error("SummaryService", "Failed to save summary: \(error.localizedDescription)")
                return ("", ErrorMessages.format(ErrorMessages.Summary.saveFailed, error.localizedDescription))
            }

            // Return empty streaming text on success (cleared)
            return ("", nil)

        } catch {
            Logger.error("SummaryService", "Summary generation failed: \(error.localizedDescription)")
            return ("", ErrorMessages.format(ErrorMessages.Summary.generationFailed, error.localizedDescription))
        }
    }
}
