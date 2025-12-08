//
//  TranscriptionProgressManager.swift
//  Transcription App
//
//  Created by Claude on 12/8/25.
//

import Foundation
import Combine

/// Singleton to track active transcription progress across views
class TranscriptionProgressManager: ObservableObject {
    static let shared = TranscriptionProgressManager()

    @Published private(set) var activeTranscriptions: [UUID: Double] = [:]

    private init() {}

    func updateProgress(for recordingId: UUID, progress: Double) {
        DispatchQueue.main.async {
            self.activeTranscriptions[recordingId] = progress
        }
    }

    func completeTranscription(for recordingId: UUID) {
        DispatchQueue.main.async {
            self.activeTranscriptions.removeValue(forKey: recordingId)
        }
    }

    func getProgress(for recordingId: UUID) -> Double? {
        return activeTranscriptions[recordingId]
    }
}
