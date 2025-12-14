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
        isGeneratingSummary = true
        summaryError = nil
        streamingSummary = ""

        let result = await SummaryService.shared.generateSummary(
            for: recording,
            modelContext: modelContext
        ) { [weak self] (chunk: String) in
            guard let self = self else { return }
            self.streamingSummary += chunk
        }

        streamingSummary = result.streamingSummary
        summaryError = result.error
        isGeneratingSummary = false

        Logger.info("SummaryViewModel", "Summary generation complete. Error: \(summaryError ?? "none"), Summary length: \(recording.summary?.count ?? 0)")
    }
}

