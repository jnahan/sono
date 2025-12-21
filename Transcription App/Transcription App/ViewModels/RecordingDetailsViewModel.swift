import Foundation
import SwiftUI
import SwiftData

/// ViewModel for RecordingDetailsView handling summary generation
class RecordingDetailsViewModel: ObservableObject {
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
    
    /// Generates a summary for the recording
    /// - Parameter modelContext: The SwiftData model context to save changes
    @MainActor
    func generateSummary(modelContext: ModelContext) async {
        guard !recording.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            summaryError = "Cannot generate summary: transcription is empty."
            return
        }

        isGeneratingSummary = true
        summaryError = nil

        do {
            // Check if transcription exceeds max input length
            if recording.fullText.count > AppConstants.LLM.maxInputCharacters {
                // Set both error and summary message before updating state
                recording.summary = "Transcription is too long to summarize"
                summaryError = "Transcription is too long to summarize. Maximum length is approximately \(AppConstants.LLM.maxInputCharacters) characters (\(recording.fullText.count) characters in transcript)."

                // Save the failure message
                do {
                    try modelContext.save()
                } catch {
                    summaryError = "Failed to save: \(error.localizedDescription)"
                }

                isGeneratingSummary = false
                return
            }

            // Format prompt to explicitly request summarization
            let prompt = "Please summarize the following text:\n\n\(recording.fullText)"

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

            // Log the actual response for debugging
            Logger.info("RecordingDetailsViewModel", "LLM response length: \(summary.count), content: \(summary.prefix(100))")

            // Validate response
            guard LLMResponseValidator.isValid(summary) else {
                Logger.warning("RecordingDetailsViewModel", "Invalid LLM response: '\(summary)' (length: \(summary.count))")
                summaryError = "Model returned invalid response. Please try again."
                isGeneratingSummary = false
                return
            }

            // Use full summary without truncation
            recording.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)

            // Clear streaming text
            streamingSummary = ""

            // Save to database (already on MainActor, no need to wrap)
            do {
                try modelContext.save()
            } catch {
                summaryError = "Failed to save summary: \(error.localizedDescription)"
            }
            
        } catch {
            summaryError = "Failed to generate summary: \(error.localizedDescription)"
            streamingSummary = ""
        }
        
        isGeneratingSummary = false
    }
}
