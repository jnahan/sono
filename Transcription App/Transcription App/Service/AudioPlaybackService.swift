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
            print("⚠️ [AudioPlayback] File not found: \(url.path)")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            currentURL = url
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            currentTime = 0
            progress = 0
            print("✅ [AudioPlayback] Preloaded: \(url.lastPathComponent)")
        } catch {
            print("❌ [AudioPlayback] Failed to load: \(error)")
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
        guard let player else { return }

        player.play()
        isPlaying = true
        startProgressTracking()
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
        guard let player else { return }

        currentTime = player.currentTime
        progress = player.duration > 0 ? player.currentTime / player.duration : 0

        // Auto-stop when finished
        if !player.isPlaying && isPlaying {
            isPlaying = false
            stopProgressTracking()
        }
    }
}
