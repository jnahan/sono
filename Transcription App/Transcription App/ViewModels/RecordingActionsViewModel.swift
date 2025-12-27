import SwiftUI
import SwiftData

/// Shared view model for recording actions (copy, share, export, retry, delete)
/// Used across RecordingListView, RecordingRowView, and RecordingDetailsView
class RecordingActionsViewModel: ObservableObject {
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

    // MARK: - Recovery State
    private static var hasRecoveredThisSession = false
    
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
        HapticFeedback.success()
        showCopyToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showCopyToast = false
        }
    }

    /// Shares a recording's transcription
    /// - Parameter recording: The recording to share
    func shareTranscription(_ recording: Recording) {
        HapticFeedback.light()
        ShareHelper.shareTranscription(recording.fullText, title: recording.title)
    }

    /// Exports a recording's audio file
    /// - Parameter recording: The recording to export
    func exportAudio(_ recording: Recording) {
        HapticFeedback.light()
        if let url = recording.resolvedURL {
            ShareHelper.shareFile(at: url)
        }
    }

    /// Retries transcription for a recording
    /// - Parameter recording: The recording to re-transcribe
    @MainActor func retryTranscription(_ recording: Recording) {
        guard let modelContext = modelContext else { return }
        guard let audioURL = recording.resolvedURL else { return }

        // Reset status
        recording.status = .inProgress
        recording.failureReason = nil
        recording.transcriptionStartedAt = Date()

        do {
            try modelContext.save()
        } catch {
            Logger.error("RecordingActionsViewModel", "Failed to save retry state: \(error.localizedDescription)")
            return
        }

        // Start transcription
        startBackgroundTranscription(for: recording, modelContext: modelContext)
    }

    /// Deletes a recording and cancels any active transcription
    /// - Parameter recording: The recording to delete
    @MainActor func deleteRecording(_ recording: Recording) {
        // Cancel any active transcription for this recording
        TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)
        modelContext?.delete(recording)
    }
    
    /// Displays a copy confirmation toast
    func displayCopyToast() {
        showCopyToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showCopyToast = false
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
        HapticFeedback.success()
        displayCopyToast()
    }
    
    /// Export multiple recordings' transcriptions as .txt files
    /// - Parameter recordings: The recordings to export
    func exportRecordings(_ recordings: [Recording]) {
        guard !recordings.isEmpty else { return }

        HapticFeedback.light()

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
    /// Only runs ONCE per app session to avoid duplicate transcription attempts
    @MainActor
    func recoverIncompleteRecordings(_ recordings: [Recording]) {
        // Only recover once per app session - don't re-run on every view appear
        guard !Self.hasRecoveredThisSession else {
            return
        }

        guard let modelContext = modelContext else {
            Logger.warning("RecordingActionsViewModel", ErrorMessages.Transcription.noModelContext)
            return
        }

        // Mark as recovered for this session
        Self.hasRecoveredThisSession = true

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

        let transcriptionTask = Task { @MainActor in
            do {
                let result = try await performTranscription(for: recordingId, audioURL: url)
                try await updateRecordingWithResult(recordingId: recordingId, result: result, modelContext: modelContext)
            } catch is CancellationError {
                Logger.info("Auto-Start", "Transcription cancelled for recording: \(recordingId.uuidString.prefix(8))")
                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            } catch {
                await handleTranscriptionFailure(recordingId: recordingId, error: error, modelContext: modelContext)
            }
        }

        TranscriptionProgressManager.shared.registerTask(for: recordingId, task: transcriptionTask)
        // Initialize progress tracking so UI can display progress
        TranscriptionProgressManager.shared.setActiveTranscription(recordingId: recordingId)
    }

    @MainActor
    private func performTranscription(for recordingId: UUID, audioURL: URL) async throws -> TranscriptionResult {
        Logger.info("Auto-Start", "Starting transcription for: \(audioURL.lastPathComponent)")

        let result = try await TranscriptionService.shared.transcribe(audioURL: audioURL, recordingId: recordingId) { progress in
            Task { @MainActor in
                if Task.isCancelled { return }
                TranscriptionProgressManager.shared.updateProgress(for: recordingId, progress: progress)
            }
        }

        try Task.checkCancellation()
        return result
    }

    @MainActor
    private func updateRecordingWithResult(recordingId: UUID, result: TranscriptionResult, modelContext: ModelContext) async throws {
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { r in r.id == recordingId }
        )

        guard let existingRecordings = try? modelContext.fetch(descriptor),
              let existingRecording = existingRecordings.first else {
            Logger.info("Auto-Start", ErrorMessages.Transcription.recordingDeleted)
            TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            return
        }

        Logger.info("Auto-Start", "Transcription result - text length: \(result.text.count), segments: \(result.segments.count)")
        existingRecording.fullText = result.text
        existingRecording.language = result.language
        existingRecording.status = .completed
        existingRecording.failureReason = nil

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
    }

    @MainActor
    private func handleTranscriptionFailure(recordingId: UUID, error: Error, modelContext: ModelContext) async {
        Logger.error("Auto-Start", "Transcription error: \(error.localizedDescription)")

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
                Logger.error("RecordingActionsViewModel", "Failed to save transcription error state: \(error.localizedDescription)")
            }
        }

        TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
    }
}
