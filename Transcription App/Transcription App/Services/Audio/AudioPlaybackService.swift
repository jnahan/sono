//
//  AudioPlaybackService.swift
//  Transcription App
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
        // Validate URL
        guard !url.path.isEmpty else {
            Logger.error("AudioPlayback", "Invalid URL: path is empty")
            return
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.warning("AudioPlayback", "File not found: \(url.path)")
            return
        }
        
        // Check file size to ensure it's not empty
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int64,
           fileSize == 0 {
            Logger.error("AudioPlayback", "File is empty: \(url.path)")
            return
        }

        do {
            // Ensure we have a proper file URL first
            let fileURL: URL
            if url.isFileURL {
                fileURL = url
            } else {
                // Convert to file URL if needed
                fileURL = URL(fileURLWithPath: url.path)
            }
            
            // Verify the file URL is valid
            guard fileURL.isFileURL else {
                Logger.error("AudioPlayback", "Invalid file URL: \(fileURL)")
                return
            }
            
            // Create the player first (this doesn't require audio session)
            player = try AVAudioPlayer(contentsOf: fileURL)
            currentURL = fileURL
            
            // Configure audio session for playback - do this AFTER creating the player
            let session = AVAudioSession.sharedInstance()
            
            // Only change category if it's different
            if session.category != .playback {
                // Deactivate first
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                
                // Set category
                try session.setCategory(.playback, mode: .default, options: [.allowBluetooth])
            }
            
            // Try to activate - if it fails, that's okay, player might still work
            do {
                try session.setActive(true)
            } catch {
                // Log but don't fail - player might still work
                Logger.warning("AudioPlayback", "Could not activate audio session: \(error.localizedDescription)")
            }
            
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
            Logger.error("AudioPlayback", "URL: \(url.path)")
            Logger.error("AudioPlayback", "Error details: \(error)")
            if let nsError = error as NSError? {
                Logger.error("AudioPlayback", "Error code: \(nsError.code), domain: \(nsError.domain)")
            }
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
            let session = AVAudioSession.sharedInstance()
            
            // Only change category if it's different
            if session.category != .playback {
                // Deactivate session first
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                
                // Configure audio session for playback
                try session.setCategory(.playback, mode: .default, options: [.allowBluetooth])
            }
            
            // Try to activate - if it fails, that's okay
            do {
                try session.setActive(true)
            } catch {
                Logger.warning("AudioPlayback", "Could not activate audio session in play(): \(error.localizedDescription)")
                // Continue anyway - player might still work
            }
            
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
