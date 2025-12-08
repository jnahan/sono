import Foundation
import SwiftData
import SwiftUI

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
    
    /// Generates a summary for the recording
    func generateSummary(modelContext: ModelContext) async {
        guard !recording.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            summaryError = "Cannot generate summary: transcription is empty."
            return
        }
        
        isGeneratingSummary = true
        summaryError = nil
        
        do {
            // Truncate transcription if needed
            let truncatedTranscription = TranscriptionHelper.truncate(
                recording.fullText,
                maxLength: AppConstants.LLM.maxContextLength
            )

            let prompt = """
            Summarize the following transcription in 2-3 concise sentences:

            \(truncatedTranscription)
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
                summaryError = "Model returned invalid response. Please try again."
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
                    summaryError = "Failed to save summary: \(error.localizedDescription)"
                }
            }
            
        } catch {
            print("❌ [SummaryView] Summary generation error: \(error)")
            summaryError = "Failed to generate summary: \(error.localizedDescription)"
            streamingSummary = ""
        }

        isGeneratingSummary = false
        print("📊 [SummaryView] Summary generation complete. Error: \(summaryError ?? "none"), Summary length: \(recording.summary?.count ?? 0)")
    }
}
