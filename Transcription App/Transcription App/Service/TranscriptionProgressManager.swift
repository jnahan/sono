//
//  TranscriptionProgressManager.swift
//  Transcription App
//
//  Created by Claude on 12/8/25.
//

import Foundation
import Combine

/// Singleton to track active transcription progress across views
@MainActor
class TranscriptionProgressManager: ObservableObject {
    static let shared = TranscriptionProgressManager()

    @Published private(set) var activeTranscriptions: [UUID: Double] = [:]
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    func updateProgress(for recordingId: UUID, progress: Double) {
        activeTranscriptions[recordingId] = progress
    }

    func completeTranscription(for recordingId: UUID) {
        activeTranscriptions.removeValue(forKey: recordingId)
        activeTasks.removeValue(forKey: recordingId)?.cancel()
    }

    func getProgress(for recordingId: UUID) -> Double? {
        return activeTranscriptions[recordingId]
    }
    
    /// Register an active transcription task for a recording
    func registerTask(for recordingId: UUID, task: Task<Void, Never>) {
        // Cancel any existing task for this recording
        activeTasks[recordingId]?.cancel()
        activeTasks[recordingId] = task
    }
    
    /// Cancel transcription for a recording (called when recording is deleted)
    func cancelTranscription(for recordingId: UUID) {
        activeTasks[recordingId]?.cancel()
        activeTasks.removeValue(forKey: recordingId)
        activeTranscriptions.removeValue(forKey: recordingId)
    }
    
    /// Check if a recording has an active transcription
    func hasActiveTranscription(for recordingId: UUID) -> Bool {
        return activeTasks[recordingId] != nil
    }
}
