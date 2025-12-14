import SwiftUI
import SwiftData

/// Shared logic for displaying and managing a list of recordings
class RecordingListViewModel: ObservableObject {
    // MARK: - Edit State
    @Published var editingRecording: Recording?
    
    // MARK: - Toast State
    @Published var showCopyToast = false
    
    // MARK: - Selection Mode State
    @Published var isSelectionMode = false
    @Published var selectedRecordings: Set<UUID> = []
    
    // MARK: - Filtering State
    @Published var searchText = ""
    @Published var filteredRecordings: [Recording] = []
    
    // MARK: - Model Context
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    /// Configures the ViewModel with a SwiftData model context
    /// - Parameter modelContext: The model context to use for database operations
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Actions
    
    /// Copies a recording's transcription text to the clipboard
    /// - Parameter recording: The recording to copy
    func copyRecording(_ recording: Recording) {
        UIPasteboard.general.string = recording.fullText
        withAnimation { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.showCopyToast = false }
        }
    }
    
    /// Sets a recording for editing
    /// - Parameter recording: The recording to edit
    func editRecording(_ recording: Recording) {
        editingRecording = recording
    }
    
    /// Deletes a recording and cancels any active transcription
    /// - Parameter recording: The recording to delete
    @MainActor func deleteRecording(_ recording: Recording) {
        // Cancel any active transcription for this recording
        TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)
        modelContext?.delete(recording)
    }
    
    /// Cancels the current edit operation
    func cancelEdit() {
        editingRecording = nil
    }
    
    /// Displays a copy confirmation toast
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
    
    /// Export multiple recordings' transcriptions as .txt files
    /// - Parameter recordings: The recordings to export
    func exportRecordings(_ recordings: [Recording]) {
        guard !recordings.isEmpty else { return }
        
        if recordings.count == 1 {
            // Single recording - use the recording title
            let recording = recordings[0]
            ShareHelper.shareTranscription(recording.fullText, title: recording.title)
        } else {
            // Multiple recordings - create separate .txt file for each
            let fileURLs = recordings.compactMap { recording -> URL? in
                ShareHelper.createTranscriptionFile(recording.fullText, title: recording.title)
            }
            
            if !fileURLs.isEmpty {
                ShareHelper.shareItems(fileURLs)
            }
        }
    }
    
    // MARK: - Selection Mode
    
    /// Enters selection mode for multi-select operations
    func enterSelectionMode() {
        isSelectionMode = true
    }
    
    /// Exits selection mode and clears all selections
    func exitSelectionMode() {
        isSelectionMode = false
        selectedRecordings.removeAll()
    }
    
    /// Toggles selection state for a recording
    /// - Parameter id: The UUID of the recording to toggle
    func toggleSelection(for id: UUID) {
        if selectedRecordings.contains(id) {
            selectedRecordings.remove(id)
        } else {
            selectedRecordings.insert(id)
        }
    }
    
    /// Checks if a recording is currently selected
    /// - Parameter id: The UUID of the recording to check
    /// - Returns: True if the recording is selected
    func isSelected(_ id: UUID) -> Bool {
        return selectedRecordings.contains(id)
    }
    
    /// Gets an array of selected recordings from a list
    /// - Parameter recordings: The full list of recordings to filter
    /// - Returns: An array containing only the selected recordings
    func selectedRecordingsArray(from recordings: [Recording]) -> [Recording] {
        return recordings.filter { selectedRecordings.contains($0.id) }
    }
    
    // MARK: - Filtering
    
    /// Update filtered recordings based on search text and source recordings
    /// - Parameter recordings: The source recordings to filter
    func updateFilteredRecordings(from recordings: [Recording]) {
        let sortedRecordings = recordings.sorted { $0.recordedAt > $1.recordedAt }
        
        if searchText.isEmpty {
            filteredRecordings = sortedRecordings
        } else {
            filteredRecordings = sortedRecordings.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.fullText.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Transcription Recovery
    
    /// Detect and recover incomplete recordings on app launch
    /// Auto-starts transcriptions for any recordings that need it
    @MainActor
    func recoverIncompleteRecordings(_ recordings: [Recording]) {
        guard let modelContext = modelContext else {
            Logger.warning("RecordingListViewModel", ErrorMessages.Transcription.noModelContext)
            return
        }
        
        // Auto-start transcriptions for any recordings that need it
        // Exclude .failed recordings - they cannot be retried
        let pendingRecordings = recordings.filter { recording in
            (recording.status == .inProgress || recording.status == .notStarted) &&
            recording.status != .failed &&
            recording.resolvedURL != nil
        }

        guard !pendingRecordings.isEmpty else { return }

        Logger.info("Auto-Start", "Found \(pendingRecordings.count) recording(s) needing transcription")

        // Auto-start transcriptions in background
        for recording in pendingRecordings {
            // Skip if already transcribing or queued
            if TranscriptionProgressManager.shared.hasActiveTranscription(for: recording.id) ||
               TranscriptionProgressManager.shared.isQueued(recordingId: recording.id) {
                continue
            }

            Logger.success("Auto-Start", "Starting transcription for: \(recording.title)")

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
            Logger.success("Recovery", "Successfully updated incomplete recordings")
        } catch {
            Logger.error("Recovery", "Failed to save recovered recordings: \(error.localizedDescription)")
        }
    }
    
    /// Start transcription in background for a recording
    @MainActor
    private func startBackgroundTranscription(for recording: Recording, modelContext: ModelContext) {
        guard let url = recording.resolvedURL else {
            Logger.error("Auto-Start", ErrorMessages.format(ErrorMessages.Transcription.noAudioURL, recording.title))
            return
        }

        let recordingId = recording.id

        // Create transcription task
        let transcriptionTask = Task { @MainActor in
            do {
                Logger.info("Auto-Start", "Starting transcription for: \(url.lastPathComponent)")
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
                    Logger.info("Auto-Start", ErrorMessages.Transcription.recordingDeleted)
                    TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
                    return
                }

                // Update recording with results
                Logger.info("Auto-Start", "Transcription result - text length: \(result.text.count), segments: \(result.segments.count)")
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
                Logger.success("Auto-Start", "Transcription completed for: \(existingRecording.title)")

            } catch is CancellationError {
                Logger.info("Auto-Start", "Transcription cancelled for recording: \(recordingId.uuidString.prefix(8))")
                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            } catch {
                Logger.error("Auto-Start", "Transcription error: \(error.localizedDescription)")

                // Check if recording still exists before updating error state
                let errorDescriptor = FetchDescriptor<Recording>(
                    predicate: #Predicate { r in r.id == recordingId }
                )

                if let errorRecordings = try? modelContext.fetch(errorDescriptor),
                   let errorRecording = errorRecordings.first {
                    errorRecording.status = .failed
                    errorRecording.failureReason = ErrorMessages.Transcription.failed

                    do {
                        try modelContext.save()
                    } catch {
                        Logger.error("RecordingListViewModel", "Failed to save transcription error state: \(error.localizedDescription)")
                    }
                }

                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            }
        }

        // Register the task for cancellation
        TranscriptionProgressManager.shared.registerTask(for: recordingId, task: transcriptionTask)
    }
}
