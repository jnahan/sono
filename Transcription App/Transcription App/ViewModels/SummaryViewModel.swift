import Foundation
import SwiftData
import SwiftUI

/// State of summary generation
enum SummaryState: Equatable {
    case idle
    case loadingModel
    case generating
    case error(String)
}

/// ViewModel for SummaryView handling AI-generated summaries
@MainActor
class SummaryViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var state: SummaryState = .idle
    @Published var summaryError: String?
    @Published var streamingSummary: String = ""
    @Published var chunkProgress: String = "" // e.g., "Processing chunk 2 of 5..."

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

    // MARK: - Public Methods
    
    /// Generates an AI summary for the recording's transcription
    /// - Parameter modelContext: The SwiftData model context to save the summary
    func generateSummary(modelContext: ModelContext) async {
        guard !recording.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            summaryError = ErrorMessages.Summary.emptyTranscription
            state = .error(ErrorMessages.Summary.emptyTranscription)
            return
        }

        // Reset ALL state to prevent contamination from previous runs
        state = .loadingModel
        summaryError = nil
        streamingSummary = ""
        chunkProgress = ""

        // Give UI time to render .loadingModel state before blocking on LLM load
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay

        do {
            let fullText = recording.fullText

            // Check if we need chunked summarization
            if fullText.count > AppConstants.LLM.maxInputCharacters {
                Logger.info("SummaryViewModel", "Using chunked summarization for \(fullText.count) characters")
                try await generateChunkedSummary(fullText: fullText, modelContext: modelContext)
            } else {
                Logger.info("SummaryViewModel", "Using standard summarization for \(fullText.count) characters")
                try await generateStandardSummary(fullText: fullText, modelContext: modelContext)
            }

        } catch {
            Logger.error("SummaryViewModel", "Summary generation error: \(error.localizedDescription)")
            let errorMessage = ErrorMessages.format(ErrorMessages.Summary.generationFailed, error.localizedDescription)
            summaryError = errorMessage
            state = .error(errorMessage)
            streamingSummary = ""
            chunkProgress = ""
            return
        }

        state = .idle
        Logger.info("SummaryViewModel", "Summary generation complete. Error: \(summaryError ?? "none"), Summary length: \(recording.summary?.count ?? 0)")
    }

    /// Standard summarization for shorter transcriptions
    private func generateStandardSummary(fullText: String, modelContext: ModelContext) async throws {
        Logger.info("SummaryViewModel", "Starting summary for recording ID: \(recording.id)")

        // Format prompt to explicitly request summarization
        let prompt = "Please summarize the following transcription:\n\n\(fullText)"

        // Reset streaming text BEFORE starting generation
        streamingSummary = ""

        // Stream the response
        let summary = try await LLMService.shared.getStreamingCompletion(
            from: prompt,
            systemPrompt: LLMPrompts.summarization,
            onModelLoaded: { [weak self] in
                Task { @MainActor in
                    self?.state = .generating
                }
            },
            onChunk: { [weak self] chunk in
                guard let self = self else { return }
                Task { @MainActor in
                    self.streamingSummary += chunk
                }
            }
        )

        // Validate response
        guard LLMResponseValidator.isValid(summary) else {
            summaryError = ErrorMessages.Summary.invalidResponse
            Logger.error("SummaryViewModel", "Invalid summary response for recording ID: \(recording.id)")
            return
        }

        // Trim whitespace
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        Logger.info("SummaryViewModel", "Saving summary for recording ID: \(recording.id), length: \(trimmedSummary.count)")

        recording.summary = trimmedSummary

        // Clear streaming text immediately after saving
        streamingSummary = ""

        // Save to database
        do {
            try modelContext.save()
            Logger.success("SummaryViewModel", "Summary saved successfully for recording ID: \(recording.id)")
        } catch {
            summaryError = ErrorMessages.format(ErrorMessages.Summary.saveFailed, error.localizedDescription)
            Logger.error("SummaryViewModel", "Failed to save summary for recording ID: \(recording.id) - \(error.localizedDescription)")
        }
    }

    /// Chunked summarization for longer transcriptions using Map-Reduce pattern
    private func generateChunkedSummary(fullText: String, modelContext: ModelContext) async throws {
        let maxChunkSize = 12000
        let chunks = TextChunker.split(fullText, maxChunkSize: maxChunkSize)
        Logger.info("SummaryViewModel", "Split into \(chunks.count) chunks")

        // Summarize each chunk
        var chunkSummaries: [String] = []
        for (index, chunk) in chunks.enumerated() {
            let summary = try await summarizeChunk(chunk, index: index, total: chunks.count)
            chunkSummaries.append(summary)
        }

        // Synthesize final summary
        try await synthesizeFinalSummary(chunkSummaries: chunkSummaries, modelContext: modelContext)
    }

    private func summarizeChunk(_ chunk: String, index: Int, total: Int) async throws -> String {
        chunkProgress = "Summarizing part \(index + 1) of \(total)..."
        Logger.info("SummaryViewModel", "Processing chunk \(index + 1)/\(total), size: \(chunk.count) chars")
        streamingSummary = ""

        let chunkPrompt: String
        if total == 1 {
            chunkPrompt = "Please summarize the following transcription:\n\n\(chunk)"
        } else {
            chunkPrompt = """
            This is part \(index + 1) of \(total) from a longer transcription.

            Please summarize the content in this section.
            The summary may be a few sentences or less, depending on how much information is present.
            Do not reference other sections.

            \(chunk)
            """
        }

        let chunkSummary = try await LLMService.shared.getStreamingCompletion(
            from: chunkPrompt,
            systemPrompt: LLMPrompts.summarization,
            onModelLoaded: { [weak self] in
                Task { @MainActor in
                    self?.state = .generating
                }
            },
            onChunk: { [weak self] streamChunk in
                guard let self = self else { return }
                Task { @MainActor in
                    self.streamingSummary += streamChunk
                }
            }
        )

        guard LLMResponseValidator.isValid(chunkSummary) else {
            throw NSError(domain: "SummaryViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response for chunk \(index + 1)"])
        }

        Logger.info("SummaryViewModel", "Chunk \(index + 1) summary: \(chunkSummary.count) chars")
        return chunkSummary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func synthesizeFinalSummary(chunkSummaries: [String], modelContext: ModelContext) async throws {
        let combinedSummaries = chunkSummaries.joined(separator: "\n\n")
        Logger.info("SummaryViewModel", "Combined summaries: \(combinedSummaries.count) chars")

        chunkProgress = "Creating final summary..."
        streamingSummary = ""

        let finalPrompt = """
        The following are summaries of different sections from a longer transcription.

        Please create a single, concise summary that:
        - Merges overlapping ideas
        - Removes repetition
        - Reflects the overall intent of the transcription

        The final result should be no longer than one short paragraph.

        \(combinedSummaries)
        """

        let finalSummary = try await LLMService.shared.getStreamingCompletion(
            from: finalPrompt,
            systemPrompt: LLMPrompts.summarization,
            onModelLoaded: { [weak self] in
                Task { @MainActor in
                    self?.state = .generating
                }
            },
            onChunk: { [weak self] chunk in
                guard let self = self else { return }
                Task { @MainActor in
                    self.streamingSummary += chunk
                }
            }
        )

        guard LLMResponseValidator.isValid(finalSummary) else {
            summaryError = ErrorMessages.Summary.invalidResponse
            Logger.error("SummaryViewModel", "Invalid final summary response for recording ID: \(recording.id)")
            return
        }

        let trimmedSummary = finalSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        Logger.info("SummaryViewModel", "Saving chunked summary for recording ID: \(recording.id), length: \(trimmedSummary.count)")

        recording.summary = trimmedSummary

        // Clear all streaming state immediately
        streamingSummary = ""
        chunkProgress = ""

        do {
            try modelContext.save()
            Logger.success("SummaryViewModel", "Chunked summary saved successfully for recording ID: \(recording.id)")
        } catch {
            summaryError = ErrorMessages.format(ErrorMessages.Summary.saveFailed, error.localizedDescription)
            Logger.error("SummaryViewModel", "Failed to save chunked summary for recording ID: \(recording.id) - \(error.localizedDescription)")
        }
    }
}

