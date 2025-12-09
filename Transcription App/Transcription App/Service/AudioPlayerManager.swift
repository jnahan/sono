import Foundation
import SwiftUI
import SwiftData

/// Global manager for audio playback across the app
/// Handles navigation triggers and tracking active recording details view state
@MainActor
class AudioPlayerManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = AudioPlayerManager()
    
    // MARK: - Published Properties
    
    /// The currently active recording being played globally
    @Published var currentRecording: Recording?
    
    /// The global audio player instance
    @Published var player = Player()
    
    /// The ID of the recording currently displayed in details view (used to hide preview bar)
    @Published var activeRecordingDetailsId: UUID? = nil
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    private init() {}
    
    /// Stop playback and clear current recording
    func stop() {
        player.stop()
        currentRecording = nil
    }
    
    /// Clear active recording details (called when leaving details view)
    func clearActiveRecordingDetails() {
        activeRecordingDetailsId = nil
    }
}

