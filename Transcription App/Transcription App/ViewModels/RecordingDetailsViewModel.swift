import Foundation
import SwiftUI
import SwiftData

/// ViewModel for RecordingDetailsView handling summary generation
class RecordingDetailsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isGeneratingSummary = false
    @Published var summaryError: String?
    
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
            // Truncate long transcriptions to fit context window
            let maxInputLength = 3000
            let transcriptionText: String
            
            if recording.fullText.count > maxInputLength {
                let beginningLength = Int(Double(maxInputLength) * 0.6)
                let endLength = maxInputLength - beginningLength - 50
                let beginning = String(recording.fullText.prefix(beginningLength))
                let end = String(recording.fullText.suffix(endLength))
                transcriptionText = "\(beginning)\n\n[...]\n\n\(end)"
            } else {
                transcriptionText = recording.fullText
            }
            
            let systemPrompt = "You are a summarization assistant. Write summaries directly without any preamble."
            
            let prompt = """
            Summarize the following transcription in 2-3 concise sentences:

            \(transcriptionText)
            """
            
            let summary = try await LLMService.shared.getCompletion(
                from: prompt,
                systemPrompt: systemPrompt
            )
            
            // Validate response
            let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !trimmedSummary.isEmpty, trimmedSummary.count >= 10 else {
                summaryError = "Model returned invalid response. Please try again."
                isGeneratingSummary = false
                return
            }
            
            // Limit summary length
            let finalSummary = trimmedSummary.count > 500
                ? String(trimmedSummary.prefix(500)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
                : trimmedSummary
            
            recording.summary = finalSummary
            
            try modelContext.save()
            
        } catch {
            summaryError = "Failed to generate summary: \(error.localizedDescription)"
        }
        
        isGeneratingSummary = false
    }
}
