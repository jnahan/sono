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
}
