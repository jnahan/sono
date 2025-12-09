//
//  AudioPlaybackService.swift
//  Transcription App
//
//  Created by Claude on 12/8/25.
//

import Combine
import SwiftUI
import AVFoundation

/// Service for managing audio playback
/// Handles playing, pausing, seeking, and progress tracking for audio recordings
final class AudioPlaybackService: ObservableObject {

    // MARK: - Published Properties

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0

    // MARK: - Private Properties

    private var player: AVAudioPlayer?
    private var progressTimer: AnyCancellable?
    private var currentURL: URL?

    // MARK: - Lifecycle

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Preloads an audio file without playing it
    /// - Parameter url: URL of the audio file to preload
    func preload(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.warning("AudioPlayback", "File not found: \(url.path)")
            return
        }

        do {
            // Configure audio session for playback
            let session = AVAudioSession.sharedInstance()
            
            // Deactivate first to ensure clean state
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Use .playback category for pure playback (not .playAndRecord)
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth])
            try session.setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url)
            currentURL = url
            
            // Enable rate and enable metering if needed
            player?.enableRate = false
            player?.numberOfLoops = 0
            
            let prepared = player?.prepareToPlay() ?? false
            duration = player?.duration ?? 0
            currentTime = 0
            progress = 0
            
            if prepared {
                Logger.success("AudioPlayback", "Preloaded: \(url.lastPathComponent), duration: \(duration)s")
            } else {
                Logger.warning("AudioPlayback", "Preloaded but prepareToPlay() returned false")
            }
        } catch {
            Logger.error("AudioPlayback", "Failed to load: \(error.localizedDescription)")
            player = nil
            currentURL = nil
        }
    }

    /// Plays audio from URL or toggles pause if already playing
    /// - Parameter url: URL of the audio file to play
    func togglePlayback(url: URL?) {
        guard let url else { return }

        // Toggle pause if playing the same file
        if isPlaying, currentURL == url {
            pause()
            return
        }

        // Load and play new file
        if currentURL != url {
            stop()
            preload(url: url)
        }

        play()
    }

    /// Plays the currently loaded audio
    func play() {
        guard let player else {
            Logger.warning("AudioPlayback", "Cannot play - no player loaded")
            return
        }

        do {
            // Deactivate session first to ensure clean state
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Configure audio session for playback
            // Use .playback category for pure playback
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth])
            try session.setActive(true)
            
            Logger.success("AudioPlayback", "Audio session configured and activated")
        } catch {
            Logger.warning("AudioPlayback", "Failed to configure audio session: \(error.localizedDescription)")
            return
        }

        // Ensure player is prepared
        if !player.prepareToPlay() {
            Logger.warning("AudioPlayback", "prepareToPlay() returned false")
        }
        
        let success = player.play()
        if success {
            // Verify player is actually playing after a brief moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self, let player = self.player else { return }
                if player.isPlaying {
                    self.isPlaying = true
                    self.startProgressTracking()
                    Logger.success("AudioPlayback", "Started playing - verified isPlaying=true")
                } else {
                    Logger.error("AudioPlayback", "player.play() returned true but isPlaying=false")
                    self.isPlaying = false
                }
            }
        } else {
            Logger.error("AudioPlayback", "player.play() returned false")
            isPlaying = false
        }
    }

    /// Pauses playback
    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTracking()
    }

    /// Stops playback and resets state
    func stop() {
        player?.stop()
        isPlaying = false
        progress = 0
        currentTime = 0
        stopProgressTracking()
        player = nil
        currentURL = nil
    }

    /// Seeks to a specific time
    /// - Parameter time: Time in seconds to seek to
    func seek(to time: TimeInterval) {
        guard let player else { return }

        player.currentTime = min(max(time, 0), player.duration)
        updateProgress()
    }

    /// Skips forward by a specified duration
    /// - Parameter seconds: Number of seconds to skip forward
    func skipForward(by seconds: TimeInterval = 15) {
        guard let player else { return }
        seek(to: player.currentTime + seconds)
    }

    /// Skips backward by a specified duration
    /// - Parameter seconds: Number of seconds to skip backward
    func skipBackward(by seconds: TimeInterval = 15) {
        guard let player else { return }
        seek(to: player.currentTime - seconds)
    }

    // MARK: - Private Methods

    private func startProgressTracking() {
        stopProgressTracking()

        progressTimer = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateProgress()
            }
    }

    private func stopProgressTracking() {
        progressTimer?.cancel()
        progressTimer = nil
    }

    private func updateProgress() {
        guard let player else {
            // Player was deallocated, stop tracking
            isPlaying = false
            stopProgressTracking()
            return
        }

        // Sync isPlaying state with actual player state
        if player.isPlaying != isPlaying {
            isPlaying = player.isPlaying
            if !isPlaying {
                stopProgressTracking()
            }
        }

        currentTime = player.currentTime
        progress = player.duration > 0 ? player.currentTime / player.duration : 0

        // Auto-stop when finished
        if !player.isPlaying && isPlaying {
            isPlaying = false
            stopProgressTracking()
            Logger.success("AudioPlayback", "Playback finished")
        }
    }
}
