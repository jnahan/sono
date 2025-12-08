import Foundation
import SwiftUI
import SwiftData
import Combine

/// Global manager for audio playback across the app
@MainActor
class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    @Published var currentRecording: Recording?
    @Published var player = Player() {
        didSet {
            // Forward player's objectWillChange to trigger UI updates
            player.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &cancellables)
        }
    }
    @Published var activeRecordingDetailsId: UUID? = nil // Track which recording is in details view
    @Published var navigateToRecording: Recording? = nil // Trigger navigation to recording details
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Forward player's objectWillChange to trigger UI updates when player state changes
        player.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }
    
    /// Play a recording. If already playing, toggles pause.
    func playRecording(_ recording: Recording) {
        guard let url = recording.resolvedURL else { return }
        
        // If playing the same recording, toggle pause
        if player.isPlaying, currentRecording?.id == recording.id {
            player.pause()
            return
        }
        
        // If different recording, stop current and play new
        if currentRecording?.id != recording.id {
            player.stop()
            currentRecording = recording
            player.loadAudio(url: url)
        }
        
        player.play(url)
    }
    
    /// Stop playback and clear current recording
    func stop() {
        player.stop()
        currentRecording = nil
    }
    
    /// Pause playback
    func pause() {
        player.pause()
    }
    
    /// Navigate to recording details - stops global player if different recording
    func navigateToRecordingDetails(_ recording: Recording) {
        // If playing a different recording, stop it
        if let current = currentRecording, current.id != recording.id {
            stop()
        }
        // Set active details ID to hide preview bar
        activeRecordingDetailsId = recording.id
        // Trigger navigation
        navigateToRecording = recording
    }
    
    /// Clear active recording details (called when leaving details view)
    func clearActiveRecordingDetails() {
        activeRecordingDetailsId = nil
        navigateToRecording = nil
    }
}

