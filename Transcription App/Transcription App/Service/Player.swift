import Combine
import SwiftUI
import AVFoundation

/// Handles audio playback for recorded files
final class Player: ObservableObject {
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    // MARK: - Private Properties
    private var player: AVAudioPlayer?
    private var timer: AnyCancellable?
    private var currentURL: URL?
    
    // MARK: - Public Methods
    
    /// Preload an audio file without playing it
    func loadAudio(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            currentURL = url
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            currentTime = 0
            progress = 0
        } catch {
            // Failed to load audio - error handled silently
        }
    }
    
    /// Play audio from a URL. If already playing the same URL, toggles pause.
    func play(_ url: URL?) {
        guard let url else { return }
        
        // If playing the same URL, toggle pause
        if isPlaying, currentURL == url {
            pause()
            return
        }
        
        // If it's a different URL, stop current and load new
        if currentURL != url {
            stop()
            loadAudio(url: url)
        }
        
        player?.play()
        isPlaying = true
        startUpdatingProgress()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopUpdatingProgress()
    }
    
    func stop() {
        player?.stop()
        isPlaying = false
        progress = 0
        currentTime = 0
        stopUpdatingProgress()
        player = nil
        currentURL = nil
    }
    
    /// Seek to a specific progress (0.0 to 1.0)
    func seek(to prog: Double) {
        guard let player, player.duration > 0 else { return }
        player.currentTime = prog * player.duration
        progress = prog
        currentTime = player.currentTime
    }
    
    /// Seek to a specific time in seconds
    func seek(toTime time: TimeInterval) {
        guard let player else { return }
        player.currentTime = time
        currentTime = time
        progress = player.duration > 0 ? time / player.duration : 0
    }
    
    /// Skip forward or backward by a number of seconds
    func skip(by seconds: TimeInterval) {
        guard let player else { return }
        let newTime = max(0, min(duration, currentTime + seconds))
        seek(toTime: newTime)
    }
    
    // MARK: - Private Methods
    private func startUpdatingProgress() {
        stopUpdatingProgress()
        
        timer = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let player = self.player else { return }
                
                if player.isPlaying {
                    self.currentTime = player.currentTime
                    self.progress = player.duration > 0 ? player.currentTime / player.duration : 0
                } else {
                    self.isPlaying = false
                    self.stopUpdatingProgress()
                }
            }
    }
    
    private func stopUpdatingProgress() {
        timer?.cancel()
        timer = nil
    }
}
