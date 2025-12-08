import Foundation
import SwiftUI
import SwiftData

/// Global manager for audio playback across the app
/// Note: Most playback functionality removed after removing AudioPreviewBar.
/// This now only handles navigation triggers and tracking active recording details.
@MainActor
class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    @Published var currentRecording: Recording?
    @Published var player = Player()
    @Published var activeRecordingDetailsId: UUID? = nil // Track which recording is in details view
    @Published var navigateToRecording: Recording? = nil // Trigger navigation to recording details
    @Published var shouldNavigateAfterRecorderDismiss: Recording? = nil // Navigate after RecorderView is dismissed
    
    private init() {}
    
    /// Stop playback and clear current recording
    func stop() {
        player.stop()
        currentRecording = nil
    }
    
    /// Clear active recording details (called when leaving details view)
    func clearActiveRecordingDetails() {
        activeRecordingDetailsId = nil
        navigateToRecording = nil
    }
}

