import Foundation
import SwiftUI
import SwiftData

/// ViewModel for RecordingDetailsView handling summary generation and audio sync
class RecordingDetailsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isGeneratingSummary = false
    @Published var summaryError: String?
    @Published var streamingSummary: String = ""
    
    /// The ID of the currently active transcript segment during audio playback
    @Published var currentActiveSegmentId: UUID?
    
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
            // Check if transcription exceeds max context length
            if recording.fullText.count > AppConstants.LLM.maxContextLength {
                recording.summary = "Failed to summarize recording"
                isGeneratingSummary = false

                // Save the failure message
                await MainActor.run {
                    do {
                        try modelContext.save()
                    } catch {
                        summaryError = "Failed to save: \(error.localizedDescription)"
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
            summaryError = "Failed to generate summary: \(error.localizedDescription)"
            streamingSummary = ""
        }
        
        isGeneratingSummary = false
    }
    
    // MARK: - Audio Sync Methods
    
    /// Updates the active segment based on current playback time
    /// - Parameters:
    ///   - currentTime: Current playback time in seconds
    ///   - isPlaying: Whether audio is currently playing
    ///   - showTimestamps: Whether timestamps are enabled
    /// - Returns: The ID of the active segment, or nil if no segment is active
    @MainActor
    func updateActiveSegment(
        currentTime: TimeInterval,
        isPlaying: Bool,
        showTimestamps: Bool
    ) -> UUID? {
        guard isPlaying && showTimestamps && !recording.segments.isEmpty else {
            return nil
        }
        
        let sortedSegments = recording.segments.sorted(by: { $0.start < $1.start })
        if let activeSegment = sortedSegments.first(where: { segment in
            currentTime >= segment.start && currentTime < segment.end
        }) {
            // Only update if this is a new active segment
            if currentActiveSegmentId != activeSegment.id {
                currentActiveSegmentId = activeSegment.id
            }
            return activeSegment.id
        }
        
        return nil
    }
    
    /// Checks if a segment is currently active based on playback time
    /// - Parameters:
    ///   - segment: The segment to check
    ///   - currentTime: Current playback time in seconds
    ///   - isPlaying: Whether audio is currently playing
    /// - Returns: True if the segment is active
    func isSegmentActive(
        segment: RecordingSegment,
        currentTime: TimeInterval,
        isPlaying: Bool
    ) -> Bool {
        return isPlaying &&
               currentTime >= segment.start &&
               currentTime < segment.end
    }
    
    /// Resets the active segment (called when playback stops)
    @MainActor
    func resetActiveSegment() {
        currentActiveSegmentId = nil
    }
    
    /// Sets the active segment manually (e.g., when user taps a segment)
    /// - Parameter segmentId: The ID of the segment to set as active
    @MainActor
    func setActiveSegment(_ segmentId: UUID) {
        currentActiveSegmentId = segmentId
    }
}
