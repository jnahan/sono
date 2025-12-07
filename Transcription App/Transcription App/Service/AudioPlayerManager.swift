import Foundation
import SwiftUI
import SwiftData

/// Global manager for audio playback across the app
@MainActor
class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    @Published var currentRecording: Recording?
    @Published var player = Player()
    
    private init() {}
    
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
}

