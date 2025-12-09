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
    @Published private(set) var queuedRecordings: Set<UUID> = []
    @Published private(set) var queuePositions: [UUID: Int] = [:]
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    func updateProgress(for recordingId: UUID, progress: Double) {
        guard progress >= 0 && progress <= 1.0 else {
            Logger.warning("ProgressManager", ErrorMessages.format(ErrorMessages.Progress.invalidProgressValue, progress, recordingId.uuidString.prefix(8)))
            return
        }
        activeTranscriptions[recordingId] = progress
    }

    func completeTranscription(for recordingId: UUID) {
        activeTranscriptions.removeValue(forKey: recordingId)
        activeTasks.removeValue(forKey: recordingId)?.cancel()
        // Also clean up queue state
        removeFromQueue(recordingId: recordingId)
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
        removeFromQueue(recordingId: recordingId)
        
        // Also notify TranscriptionService to remove from its queue
        Task {
            TranscriptionService.shared.cancelTranscription(recordingId: recordingId)
        }
    }
    
    /// Check if a recording has an active transcription
    func hasActiveTranscription(for recordingId: UUID) -> Bool {
        return activeTasks[recordingId] != nil
    }
    
    /// Add a recording to the queue
    func addToQueue(recordingId: UUID, position: Int) {
        guard position > 0 else {
            Logger.warning("ProgressManager", ErrorMessages.format(ErrorMessages.Progress.invalidQueuePosition, position, recordingId.uuidString.prefix(8)))
            return
        }
        queuedRecordings.insert(recordingId)
        queuePositions[recordingId] = position
    }

    /// Remove a recording from the queue
    func removeFromQueue(recordingId: UUID) {
        queuedRecordings.remove(recordingId)
        queuePositions.removeValue(forKey: recordingId)
    }

    /// Update queue position for a recording (non-blocking, fire-and-forget)
    func updateQueuePosition(recordingId: UUID, position: Int) {
        guard position > 0 else {
            // Silently ignore invalid positions - this is fire-and-forget
            return
        }
        // Only update if still in queue
        if queuedRecordings.contains(recordingId) {
            queuePositions[recordingId] = position
        }
    }
    
    /// Get queue position for a recording
    func getQueuePosition(for recordingId: UUID) -> Int? {
        return queuePositions[recordingId]
    }
    
    /// Check if a recording is queued
    func isQueued(recordingId: UUID) -> Bool {
        return queuedRecordings.contains(recordingId)
    }

    /// Get total number of items in queue + active transcription
    func getTotalQueueSize() -> Int {
        return queuedRecordings.count + (activeTranscriptions.isEmpty ? 0 : 1)
    }

    /// Get position in overall queue (1-indexed) - includes active transcription as position 1
    func getOverallPosition(for recordingId: UUID) -> Int? {
        // If it's actively transcribing, it's position 1
        if activeTranscriptions[recordingId] != nil {
            return 1
        }

        // If it's in queue, return its position + 1 (because active transcription is first)
        if let queuePos = queuePositions[recordingId] {
            return queuePos + 1
        }

        return nil
    }
}
