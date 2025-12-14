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
            Logger.warning("ProgressManager", ErrorMessages.format(ErrorMessages.Progress.invalidProgressValue, progress, String(recordingId.uuidString.prefix(8))))
            return
        }
        // Only log significant progress updates (every 10%) to avoid log spam
        let currentProgress = activeTranscriptions[recordingId] ?? 0.0
        if progress == 1.0 || progress == 0.0 || abs(progress - currentProgress) >= 0.1 {
            Logger.info("ProgressManager", "Progress update for \(recordingId.uuidString.prefix(8)): \(Int(progress * 100))%")
        }
        activeTranscriptions[recordingId] = progress
    }

    func completeTranscription(for recordingId: UUID) {
        activeTasks.removeValue(forKey: recordingId)?.cancel()
        // Remove and update positions for remaining items
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

        // Also notify TranscriptionService to remove from its queue - must be async
        Task {
            await TranscriptionService.shared.cancelTranscription(recordingId: recordingId)
        }
    }
    
    /// Check if a recording has an active transcription
    func hasActiveTranscription(for recordingId: UUID) -> Bool {
        return activeTasks[recordingId] != nil
    }
    
    /// Add a recording to the queue
    func addToQueue(recordingId: UUID, position: Int) {
        guard position > 0 else {
            Logger.warning("ProgressManager", ErrorMessages.format(ErrorMessages.Progress.invalidQueuePosition, position, String(recordingId.uuidString.prefix(8))))
            return
        }
        Logger.info("ProgressManager", "Adding \(recordingId.uuidString.prefix(8)) to queue at position \(position)")
        queuedRecordings.insert(recordingId)
        queuePositions[recordingId] = position
    }
    
    /// Mark a recording as active (removes from queued)
    func setActiveTranscription(recordingId: UUID) {
        // When item becomes active, remove it from queued (it's now active, not queued)
        queuedRecordings.remove(recordingId)
    }

    /// Remove a recording from the queue and update remaining positions
    func removeFromQueue(recordingId: UUID) {
        let wasActive = activeTranscriptions[recordingId] != nil
        let wasQueued = queuedRecordings.contains(recordingId)
        
        guard wasActive || wasQueued else {
            // Already removed or never was in queue
            return
        }
        
        // Get the queue position before removing (queued items have positions 1, 2, 3...)
        let removedQueuePosition = queuePositions[recordingId]
        
        // Remove from queue
        queuedRecordings.remove(recordingId)
        queuePositions.removeValue(forKey: recordingId)
        if wasActive {
            activeTranscriptions.removeValue(forKey: recordingId)
        }
        
        // Update positions for all remaining queued items
        // CRITICAL: Collect updates first, then apply to avoid modifying dictionary during iteration
        if wasActive {
            // Active item removed: all queued items move up by 1 (1→0, 2→1, 3→2, etc.)
            let updates = queuePositions.map { (id: $0.key, newPosition: $0.value - 1) }
            for update in updates {
                queuePositions[update.id] = update.newPosition
            }
        } else if let removedPos = removedQueuePosition {
            // Queued item removed: items after it move up by 1
            let updates = queuePositions.compactMap { (id, position) in
                position > removedPos ? (id: id, newPosition: position - 1) : nil
            }
            for update in updates {
                queuePositions[update.id] = update.newPosition
            }
        }
    }

    /// Check if a recording is queued
    func isQueued(recordingId: UUID) -> Bool {
        return queuedRecordings.contains(recordingId)
    }

    /// Get total number of items in queue + active transcription
    func getTotalQueueSize() -> Int {
        return queuedRecordings.count + (activeTranscriptions.isEmpty ? 0 : 1)
    }
    
    /// Get position in overall queue (1-indexed)
    /// Returns current position and current total for display
    func getOverallPosition(for recordingId: UUID) -> (position: Int, total: Int)? {
        // Use current queue size (active + queued)
        let total = getTotalQueueSize()
        guard total > 0 else { return nil }
        
        // If it's actively transcribing, it's position 1
        if activeTranscriptions[recordingId] != nil {
            return (1, total)
        }

        // If it's in queue, return its current position
        if let queuePos = queuePositions[recordingId] {
            // Position is 1-indexed: active (1) + queue position
            return (queuePos + 1, total)
        }

        return nil
    }
}
