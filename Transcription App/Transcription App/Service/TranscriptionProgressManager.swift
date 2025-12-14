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
    @Published private(set) var maxQueueTotal: Int = 0 // Shared maximum queue size across all recordings
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    func updateProgress(for recordingId: UUID, progress: Double) {
        guard progress >= 0 && progress <= 1.0 else {
            Logger.warning("ProgressManager", ErrorMessages.format(ErrorMessages.Progress.invalidProgressValue, progress, String(recordingId.uuidString.prefix(8))))
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
    func addToQueue(recordingId: UUID, position: Int, totalInQueue: Int) {
        guard position > 0, totalInQueue > 0 else {
            Logger.warning("ProgressManager", ErrorMessages.format(ErrorMessages.Progress.invalidQueuePosition, position, String(recordingId.uuidString.prefix(8))))
            return
        }
        queuedRecordings.insert(recordingId)
        queuePositions[recordingId] = position
        // Update shared max total - this is the maximum queue size ever reached
        // When total increases, all recordings should show the new total
        if totalInQueue > maxQueueTotal {
            maxQueueTotal = totalInQueue
        }
    }
    
    /// Update queue total for active transcription
    func setActiveTranscription(recordingId: UUID, totalInQueue: Int) {
        // Update shared max total - this is the maximum queue size ever reached
        // When total increases, all recordings should show the new total
        if totalInQueue > maxQueueTotal {
            maxQueueTotal = totalInQueue
        }
    }

    /// Remove a recording from the queue
    func removeFromQueue(recordingId: UUID) {
        queuedRecordings.remove(recordingId)
        queuePositions.removeValue(forKey: recordingId)
        // Don't reset maxQueueTotal - it should stay at the maximum that was ever reached
    }

    /// Update queue position for a recording (non-blocking, fire-and-forget)
    /// Position updates as items complete, but total stays at maxQueueTotal
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
    
    /// Get position in overall queue (1-indexed) - position stays at original value
    /// Returns original position and shared total for display
    func getOverallPosition(for recordingId: UUID) -> (position: Int, total: Int)? {
        // Use shared max total (the maximum queue size that was ever reached)
        let total = maxQueueTotal > 0 ? maxQueueTotal : getTotalQueueSize()
        
        // If it's actively transcribing, check if we have an original position stored
        // Otherwise, it was the first one (position 1)
        if activeTranscriptions[recordingId] != nil {
            // Check if we have a stored position (from when it was queued)
            if let originalPos = queuePositions[recordingId] {
                return (originalPos + 1, total) // +1 because active transcription is first
            } else {
                // This was the first one, position 1
                return (1, total)
            }
        }

        // If it's in queue, return its original position and shared total
        if let queuePos = queuePositions[recordingId] {
            return (queuePos + 1, total) // +1 because active transcription is first
        }

        return nil
    }
}
