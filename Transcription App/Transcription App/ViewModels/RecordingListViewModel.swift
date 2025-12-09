import SwiftUI
import SwiftData

/// Shared logic for displaying and managing a list of recordings
class RecordingListViewModel: ObservableObject {
    // MARK: - Edit State
    @Published var editingRecording: Recording?
    
    // MARK: - Toast State
    @Published var showCopyToast = false
    
    // MARK: - Model Context
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Actions
    func copyRecording(_ recording: Recording) {
        UIPasteboard.general.string = recording.fullText
        withAnimation { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.showCopyToast = false }
        }
    }
    
    func editRecording(_ recording: Recording) {
        editingRecording = recording
    }
    
    @MainActor func deleteRecording(_ recording: Recording) {
        // Cancel any active transcription for this recording
        TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)
        modelContext?.delete(recording)
    }
    
    func cancelEdit() {
        editingRecording = nil
    }
    
    func displayCopyToast() {
        withAnimation { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.showCopyToast = false }
        }
    }
    
    // MARK: - Mass Actions
    
    /// Delete multiple recordings
    @MainActor func deleteRecordings(_ recordings: [Recording]) {
        for recording in recordings {
            deleteRecording(recording)
        }
    }
    
    /// Copy multiple recordings' text to clipboard
    func copyRecordings(_ recordings: [Recording]) {
        let combinedText = recordings.map { $0.fullText }.joined(separator: "\n\n")
        UIPasteboard.general.string = combinedText
        displayCopyToast()
    }
    
    // MARK: - Transcription Recovery
    
    /// Detect and recover incomplete recordings on app launch
    /// Auto-starts transcriptions for any recordings that need it
    @MainActor
    func recoverIncompleteRecordings(_ recordings: [Recording]) {
        guard let modelContext = modelContext else {
            print("⚠️ [RecordingListViewModel] No model context configured for recovery")
            return
        }
        
        // Auto-start transcriptions for any recordings that need it
        let pendingRecordings = recordings.filter { recording in
            (recording.status == .inProgress || recording.status == .notStarted) &&
            recording.resolvedURL != nil
        }

        guard !pendingRecordings.isEmpty else { return }

        print("🔄 [Auto-Start] Found \(pendingRecordings.count) recording(s) needing transcription")

        // Auto-start transcriptions in background
        for recording in pendingRecordings {
            // Skip if already transcribing or queued
            if TranscriptionProgressManager.shared.hasActiveTranscription(for: recording.id) ||
               TranscriptionProgressManager.shared.isQueued(recordingId: recording.id) {
                continue
            }

            print("✅ [Auto-Start] Starting transcription for: \(recording.title)")

            // Clear any old failure reasons
            recording.failureReason = nil
            recording.status = .inProgress
            recording.transcriptionStartedAt = Date()

            // Start transcription in background
            startBackgroundTranscription(for: recording, modelContext: modelContext)
        }

        // Save status updates
        do {
            try modelContext.save()
            print("✅ [Recovery] Successfully updated incomplete recordings")
        } catch {
            print("❌ [Recovery] Failed to save recovered recordings: \(error)")
        }
    }
    
    /// Start transcription in background for a recording
    @MainActor
    private func startBackgroundTranscription(for recording: Recording, modelContext: ModelContext) {
        guard let url = recording.resolvedURL else {
            print("❌ [Auto-Start] No audio URL for recording: \(recording.title)")
            return
        }

        let recordingId = recording.id

        // Create transcription task
        let transcriptionTask = Task { @MainActor in
            do {
                print("🎯 [Auto-Start] Starting transcription for: \(url.lastPathComponent)")
                let result = try await TranscriptionService.shared.transcribe(audioURL: url, recordingId: recordingId) { progress in
                    Task { @MainActor in
                        if Task.isCancelled { return }
                        TranscriptionProgressManager.shared.updateProgress(for: recordingId, progress: progress)
                    }
                }

                // Check if task was cancelled
                try Task.checkCancellation()

                // Verify recording still exists before updating
                let descriptor = FetchDescriptor<Recording>(
                    predicate: #Predicate { r in r.id == recordingId }
                )

                guard let existingRecordings = try? modelContext.fetch(descriptor),
                      let existingRecording = existingRecordings.first else {
                    print("ℹ️ [Auto-Start] Recording was deleted during transcription")
                    TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
                    return
                }

                // Update recording with results
                existingRecording.fullText = result.text
                existingRecording.language = result.language
                existingRecording.status = .completed
                existingRecording.failureReason = nil

                // Clear existing segments and add new ones
                existingRecording.segments.removeAll()
                for segment in result.segments {
                    let recordingSegment = RecordingSegment(
                        start: segment.start,
                        end: segment.end,
                        text: segment.text
                    )
                    modelContext.insert(recordingSegment)
                    existingRecording.segments.append(recordingSegment)
                }

                try modelContext.save()
                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
                print("✅ [Auto-Start] Transcription completed for: \(existingRecording.title)")

            } catch is CancellationError {
                print("ℹ️ [Auto-Start] Transcription cancelled for recording: \(recordingId.uuidString.prefix(8))")
                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            } catch {
                print("❌ [Auto-Start] Transcription error: \(error)")

                // Check if recording still exists before updating error state
                let errorDescriptor = FetchDescriptor<Recording>(
                    predicate: #Predicate { r in r.id == recordingId }
                )

                if let errorRecordings = try? modelContext.fetch(errorDescriptor),
                   let errorRecording = errorRecordings.first {
                    errorRecording.status = .inProgress
                    errorRecording.failureReason = "Transcription was interrupted. Tap to resume."
                    try? modelContext.save()
                }

                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            }
        }

        // Register the task for cancellation
        TranscriptionProgressManager.shared.registerTask(for: recordingId, task: transcriptionTask)
    }
}
