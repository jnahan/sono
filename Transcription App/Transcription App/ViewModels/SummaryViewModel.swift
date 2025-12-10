import Foundation
import SwiftData
import SwiftUI

/// ViewModel for SummaryView handling AI-generated summaries
@MainActor
class SummaryViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isGeneratingSummary = false
    @Published var summaryError: String?
    @Published var streamingSummary: String = ""
    
    // MARK: - Private Properties
    
    private let recording: Recording
    
    // MARK: - Initialization
    
    init(recording: Recording) {
        self.recording = recording
    }
    
    // MARK: - Public Methods
    
    /// Generates an AI summary for the recording's transcription
    /// - Parameter modelContext: The SwiftData model context to save the summary
    func generateSummary(modelContext: ModelContext) async {
        guard !recording.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            summaryError = ErrorMessages.Summary.emptyTranscription
            return
        }
        
        isGeneratingSummary = true
        summaryError = nil

        do {
            // Check if transcription exceeds max context length
            if recording.fullText.count > AppConstants.LLM.maxContextLength {
                recording.summary = "Failed to summarize recording"
                isGeneratingSummary = false

                // Save the failure message
                await MainActor.run {
                    do {
                        try modelContext.save()
                    } catch {
                        Logger.error("SummaryViewModel", "Failed to save: \(error.localizedDescription)")
                    }
                }
                return
            }

            let prompt = """
            Summarize the following transcription in 2-3 concise sentences:

            \(recording.fullText)
            """

            // Reset streaming text
            streamingSummary = ""

            // Stream the response
            let summary = try await LLMService.shared.getStreamingCompletion(
                from: prompt,
                systemPrompt: LLMPrompts.summarization
            ) { [weak self] chunk in
                guard let self = self else { return }
                Task { @MainActor in
                    self.streamingSummary += chunk
                }
            }

            // Validate response
            guard LLMResponseValidator.isValid(summary) else {
                summaryError = ErrorMessages.Summary.invalidResponse
                isGeneratingSummary = false
                return
            }

            // Limit summary length
            let finalSummary = LLMResponseValidator.limit(
                summary,
                to: AppConstants.LLM.maxSummaryLength
            )
            
            recording.summary = finalSummary
            
            // Clear streaming text
            streamingSummary = ""
            
            // Save asynchronously to avoid blocking main thread
            await MainActor.run {
                do {
                    try modelContext.save()
                } catch {
                    summaryError = ErrorMessages.format(ErrorMessages.Summary.saveFailed, error.localizedDescription)
                }
            }
            
        } catch {
            Logger.error("SummaryViewModel", "Summary generation error: \(error.localizedDescription)")
            summaryError = ErrorMessages.format(ErrorMessages.Summary.generationFailed, error.localizedDescription)
            streamingSummary = ""
        }

        isGeneratingSummary = false
        Logger.info("SummaryViewModel", "Summary generation complete. Error: \(summaryError ?? "none"), Summary length: \(recording.summary?.count ?? 0)")
    }
}

