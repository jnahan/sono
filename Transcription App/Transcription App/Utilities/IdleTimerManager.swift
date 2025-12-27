//
//  IdleTimerManager.swift
//  Transcription App
//
//  Manages idle timer state globally based on app activity.
//  Prevents screen from auto-locking during recording or transcription.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class IdleTimerManager: ObservableObject {
    static let shared = IdleTimerManager()

    private var cancellables = Set<AnyCancellable>()

    // Track active states
    @Published private(set) var isRecording = false
    @Published private(set) var hasActiveTranscriptions = false
    @Published private(set) var isExtractingAudio = false

    // Computed: should idle timer be disabled?
    private var shouldDisableIdleTimer: Bool {
        isRecording || hasActiveTranscriptions || isExtractingAudio
    }

    private init() {
        // Monitor TranscriptionProgressManager for active transcriptions
        TranscriptionProgressManager.shared.$activeTranscriptions
            .map { !$0.isEmpty }
            .removeDuplicates()
            .sink { [weak self] hasActive in
                self?.hasActiveTranscriptions = hasActive
                self?.updateIdleTimer()
            }
            .store(in: &cancellables)
    }

    /// Call this when recording starts
    func setRecording(_ recording: Bool) {
        isRecording = recording
        updateIdleTimer()
    }

    /// Call this when audio extraction starts/ends
    func setExtracting(_ extracting: Bool) {
        isExtractingAudio = extracting
        updateIdleTimer()
    }

    /// Updates the system idle timer based on current state
    private func updateIdleTimer() {
        #if canImport(UIKit)
        let shouldDisable = shouldDisableIdleTimer

        // Only update if the state actually changed to avoid unnecessary calls
        if UIApplication.shared.isIdleTimerDisabled != shouldDisable {
            UIApplication.shared.isIdleTimerDisabled = shouldDisable

            if shouldDisable {
                Logger.info("IdleTimerManager", "Screen auto-lock disabled (recording: \(isRecording), transcriptions: \(hasActiveTranscriptions), extracting: \(isExtractingAudio))")
            } else {
                Logger.info("IdleTimerManager", "Screen auto-lock re-enabled")
            }
        }
        #endif
    }

    /// Force restore idle timer (for cleanup/safety)
    func restoreIdleTimer() {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = false
        Logger.info("IdleTimerManager", "Screen auto-lock force restored")
        #endif
    }
}
