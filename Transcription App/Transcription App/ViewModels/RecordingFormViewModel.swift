import SwiftUI
import SwiftData
import Foundation

/// ViewModel for RecordingFormView handling validation and business logic
class RecordingFormViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Form state
    @Published var title: String = "" {
        didSet {
            updateFormValidity()
        }
    }
    @Published var selectedCollection: Collection? = nil
    @Published var note: String = "" {
        didSet {
            updateFormValidity()
        }
    }
    
    // Transcription state
    @Published var transcribedText: String = ""
    @Published var transcribedLanguage: String = ""
    @Published var transcribedSegments: [RecordingSegment] = []
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0.0 // 0.0 to 1.0
    @Published var isModelLoading = false // Track if model is being downloaded/loaded
    @Published var isModelWarming = false // Track if model is warming up
    @Published var wasBackgroundedDuringTranscription = false // Track if app was backgrounded during transcription
    
    // Validation state
    @Published var titleError: String? = nil
    @Published var noteError: String? = nil
    @Published var hasAttemptedSubmit = false
    @Published var isFormValid: Bool = true // Published property that updates when title/note change
    
    // UI state
    @Published var showCollectionPicker = false
    @Published var showExitConfirmation = false
    @Published var showErrorToast = false
    @Published var errorMessage = ""
    
    // MARK: - Private Properties

    private let audioURL: URL?
    private let existingRecording: Recording?
    private var autoSavedRecording: Recording? = nil // Track auto-saved recording for recovery
    
    // MARK: - Computed Properties
    
    var isEditing: Bool {
        existingRecording != nil
    }
    
    var saveButtonText: String {
        if isEditing {
            return "Save changes"
        }

        // For new recordings, always allow saving (transcription continues in background)
        return "Save recording"
    }
    
    // MARK: - Initialization
    
    init(audioURL: URL?, existingRecording: Recording?) {
        self.audioURL = audioURL
        self.existingRecording = existingRecording
    }
    
    // MARK: - Setup
    
    func setupForm() {
        if let recording = existingRecording {
            // Pre-populate for editing
            title = recording.title
            selectedCollection = recording.collection
            note = recording.notes
            transcribedText = recording.fullText
            transcribedLanguage = recording.language
        } else if let url = audioURL {
            // For new recordings from file/video upload, use filename (without extension) as default title
            let filename = url.deletingPathExtension().lastPathComponent
            
            // For video extractions, the filename format is: {videoName}-audio-{timestamp}
            // Extract just the video name part
            if filename.contains("-audio-") {
                if let videoName = filename.components(separatedBy: "-audio-").first, !videoName.isEmpty {
                    title = videoName
                } else {
                    title = filename
                }
            } else {
                // For direct audio files, use the filename without extension
                title = filename
            }
        }
        // If no audioURL, leave title empty (will be "Untitled recording" if not filled)
        // Update form validity after setting initial values
        updateFormValidity()
    }
    
    func startTranscriptionIfNeeded() {
        if existingRecording == nil, audioURL != nil {
            startTranscription()
        }
    }
    
    // MARK: - Validation
    
    func validateTitle() -> Bool {
        let trimmed = title.trimmed
        // Allow empty title (will become "Untitled recording")
        return trimmed.isEmpty || trimmed.count <= AppConstants.Validation.maxTitleLength
    }
    
    func validateNote() -> Bool {
        return note.count <= AppConstants.Validation.maxNoteLength
    }
    
    /// Update the published isFormValid property and show errors in real-time
    private func updateFormValidity() {
        // Update title error in real-time
        let trimmedTitle = title.trimmed
        if !trimmedTitle.isEmpty {
            if let error = FormValidationHelper.validateLength(trimmedTitle, max: AppConstants.Validation.maxTitleLength, fieldName: "Title") {
                titleError = error
            } else {
                titleError = nil
            }
        } else {
            titleError = nil // Empty title is allowed
        }
        
        // Update note error in real-time
        if let error = FormValidationHelper.validateLength(note, max: AppConstants.Validation.maxNoteLength, fieldName: "Note") {
            noteError = error
        } else {
            noteError = nil
        }
        
        // Update form validity
        isFormValid = validateTitle() && validateNote()
    }
    
    @discardableResult
    func validateTitleWithError() -> Bool {
        if hasAttemptedSubmit {
            let trimmed = title.trimmed

            // Only validate length (empty is allowed - will become "Untitled recording")
            if !trimmed.isEmpty {
                if let error = FormValidationHelper.validateLength(trimmed, max: AppConstants.Validation.maxTitleLength, fieldName: "Title") {
                    titleError = error
                    return false
                }
            }

            titleError = nil
            return true
        } else {
            // Don't show errors until submit is attempted
            titleError = nil
            return validateTitle()
        }
    }
    
    @discardableResult
    func validateNoteWithError() -> Bool {
        if hasAttemptedSubmit {
            if let error = FormValidationHelper.validateLength(note, max: AppConstants.Validation.maxNoteLength, fieldName: "Note") {
                noteError = error
                return false
            }
            
            noteError = nil
            return true
        } else {
            // Don't show errors until submit is attempted
            noteError = nil
            return validateNote()
        }
    }
    
    func validateForm() {
        hasAttemptedSubmit = true
        validateTitleWithError()
        validateNoteWithError()
    }
    
    // MARK: - Transcription

    private var transcriptionModelContext: ModelContext? = nil

    func startTranscription(modelContext: ModelContext? = nil) {
        // Prevent retrying failed recordings
        if autoSavedRecording?.status == .failed {
            showError(ErrorMessages.Transcription.cannotRetranscribe)
            return
        }

        guard let url = audioURL else {
            showError("Audio file not found")
            return
        }

        // Store modelContext for background updates
        if let context = modelContext {
            transcriptionModelContext = context
        }
        
        // Start transcription - if model isn't ready, wait for it
        Task { @MainActor in
            // Check if model is ready - if so, start transcription immediately
            if TranscriptionService.shared.isModelReadyForTranscription {
                isModelLoading = false
                isModelWarming = false
                isTranscribing = true
                transcriptionProgress = 0.0
            } else {
                // Model not ready - wait for it
                // Set initial state
                let isLoading = TranscriptionService.shared.isModelLoading
                let hasModel = TranscriptionService.shared.hasModelInstance
                
                if isLoading {
                    isModelLoading = true
                    isModelWarming = false
                } else if hasModel {
                    isModelLoading = false
                    isModelWarming = true
                } else {
                    isModelLoading = true
                    isModelWarming = false
                }
                
                // Wait for model to be ready (up to 60 seconds)
                let maxWaitTime: TimeInterval = 60
                let startTime = Date()
                
                while !TranscriptionService.shared.isModelReadyForTranscription {
                    // Update state based on current service state
                    let currentIsLoading = TranscriptionService.shared.isModelLoading
                    let currentHasModel = TranscriptionService.shared.hasModelInstance
                    
                    if currentIsLoading {
                        isModelLoading = true
                        isModelWarming = false
                    } else if currentHasModel {
                        isModelLoading = false
                        isModelWarming = true
                    }
                    
                    if Date().timeIntervalSince(startTime) > maxWaitTime {
                        isModelLoading = false
                        isModelWarming = false
                        showError("Transcription model failed to load. Please restart the app")
                        return
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 seconds
                }
                
                // Model is now ready
                isModelLoading = false
                isModelWarming = false
                isTranscribing = true
                transcriptionProgress = 0.0
            }
            
            // Now transcribe with the ready model
            guard let recordingId = autoSavedRecording?.id else {
                Logger.warning("RecordingForm", "No recording ID available, cannot start transcription")
                return
            }
            
            // Create a cancellable task
            let transcriptionTask = Task { @MainActor in
                do {
                    Logger.info("RecordingForm", "Starting transcription for: \(url.lastPathComponent)")
                    let result = try await TranscriptionService.shared.transcribe(audioURL: url, recordingId: recordingId) { progress in
                        Task { @MainActor in
                            // Check if task was cancelled
                            if Task.isCancelled {
                                return
                            }
                            self.transcriptionProgress = progress
                            // Update shared progress manager for cross-view updates
                            TranscriptionProgressManager.shared.updateProgress(for: recordingId, progress: progress)
                        }
                    }
                    
                    // Check if task was cancelled before processing results
                    try Task.checkCancellation()
                    
                    Logger.success("RecordingForm", "Transcription completed successfully")
                    handleTranscriptionResult(result, modelContext: transcriptionModelContext, recordingId: recordingId)
                } catch is CancellationError {
                    Logger.info("RecordingForm", "Transcription cancelled for recording: \(recordingId.uuidString.prefix(8))")
                    // Clean up on cancellation
                    TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
                    isTranscribing = false
                } catch {
                    Logger.error("RecordingForm", "Transcription error: \(error.localizedDescription)")
                    handleTranscriptionError(error, recordingId: recordingId)
                }
            }
            
            // Register the task for cancellation
            TranscriptionProgressManager.shared.registerTask(for: recordingId, task: transcriptionTask)
        }
    }

    func setTranscriptionContext(_ context: ModelContext) {
        transcriptionModelContext = context
    }
    
    @MainActor
    private func handleTranscriptionResult(_ result: TranscriptionResult, modelContext: ModelContext?, recordingId: UUID) {
        // Check if recording still exists before updating
        guard let context = modelContext else {
            Logger.warning("RecordingForm", "No model context, cannot update recording")
            TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            return
        }
        
        // Verify recording still exists in database
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { recording in
                recording.id == recordingId
            }
        )
        
        guard let existingRecordings = try? context.fetch(descriptor),
              let recording = existingRecordings.first else {
            Logger.info("RecordingForm", ErrorMessages.Transcription.recordingDeletedDuringTranscription)
            TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            isTranscribing = false
            return
        }
        
        transcribedText = result.text
        transcribedLanguage = result.language
        transcribedSegments = result.segments.map { segment in
            RecordingSegment(
                start: segment.start,
                end: segment.end,
                text: segment.text
            )
        }
        transcriptionProgress = 1.0 // Complete
        isTranscribing = false

        Logger.success("RecordingForm", "Transcription completed - Text length: \(transcribedText.count), Segments: \(transcribedSegments.count), Language: \(transcribedLanguage)")

        // Update recording with transcription results
        recording.fullText = transcribedText
        recording.language = transcribedLanguage
        recording.status = .completed
        recording.failureReason = nil

        // Clear existing segments and add new ones
        recording.segments.removeAll()
        for segment in transcribedSegments {
            // Insert segment into context if not already tracked
            if segment.modelContext == nil {
                context.insert(segment)
            }
            recording.segments.append(segment)
        }

        do {
            try context.save()
            Logger.success("RecordingForm", "Auto-saved recording updated with transcription")

            // Mark transcription complete in progress manager
            TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
        } catch {
            Logger.error("RecordingForm", "Failed to update recording: \(error.localizedDescription)")
            TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
        }
    }
    
    @MainActor
    private func handleTranscriptionError(_ error: Error, recordingId: UUID) {
        isTranscribing = false
        isModelLoading = false
        isModelWarming = false
        transcriptionProgress = 0.0

        // Only show error if recording still exists
        if let recording = autoSavedRecording {
            // Check if recording still exists in database
            if let context = transcriptionModelContext {
                let descriptor = FetchDescriptor<Recording>(
                    predicate: #Predicate { r in
                        r.id == recordingId
                    }
                )

                if let existingRecordings = try? context.fetch(descriptor),
                   existingRecordings.first != nil {
                    // Mark as failed for actual errors
                    recording.status = .failed
                    recording.failureReason = ErrorMessages.Transcription.failed

                    // Save the context to persist the state
                    try? context.save()

                    // Show user-friendly error toast
                    showError(ErrorMessages.Transcription.failedWithDetails)

                    Logger.warning("RecordingForm", "Transcription failed: \(error.localizedDescription)")
                } else {
                    Logger.info("RecordingForm", "Recording was deleted, skipping error handling")
                }
            }
        }

        TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
    }
    
    func showError(_ message: String) {
        Task { @MainActor in
            errorMessage = message
            withAnimation {
                showErrorToast = true
            }
        }
    }

    /// Mark that the app was backgrounded during transcription
    func markBackgrounded() {
        wasBackgroundedDuringTranscription = true
    }

    /// Handle app returning from background - resume transcription if needed
    @MainActor
    func handleReturnFromBackground(modelContext: ModelContext) {
        guard let recording = autoSavedRecording else { return }

        // Check if transcription completed while backgrounded
        if recording.status == .completed {
            Logger.success("RecordingForm", "Transcription completed while backgrounded")
            isTranscribing = false
            transcriptionProgress = 1.0
            transcribedText = recording.fullText
            transcribedLanguage = recording.language
            wasBackgroundedDuringTranscription = false
            return
        }

        // If transcription was in progress and we were backgrounded, check if it's still running
        if wasBackgroundedDuringTranscription && recording.status == .inProgress {
            let recordingId = recording.id

            // Check if transcription task is still active
            if !TranscriptionProgressManager.shared.hasActiveTranscription(for: recordingId) {
                Logger.warning("RecordingForm", "Transcription was interrupted - restarting")
                // Transcription was interrupted by backgrounding - restart it
                wasBackgroundedDuringTranscription = false
                startTranscription(modelContext: modelContext)
            } else {
                Logger.info("RecordingForm", "Transcription still running after return from background")
                wasBackgroundedDuringTranscription = false
            }
        }
    }

    /// Handle low memory warning during transcription
    @MainActor
    func handleLowMemory(modelContext: ModelContext) {
        guard let recording = autoSavedRecording else { return }

        Logger.warning("RecordingForm", "Handling low memory - stopping transcription")

        // Cancel the active transcription task
        TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)

        // Update recording status to indicate interruption
        recording.status = .inProgress
        recording.failureReason = ErrorMessages.Transcription.interruptedLowMemory

        // Save the state
        do {
            try modelContext.save()
            Logger.success("RecordingForm", "Saved recording state after low memory warning")
        } catch {
            Logger.error("RecordingForm", "Failed to save recording state: \(error.localizedDescription)")
        }

        // Update UI state
        isTranscribing = false
        transcriptionProgress = 0.0
    }

    /// Auto-save a recording immediately after recording stops, before transcription
    @MainActor
    func autoSaveRecording(modelContext: ModelContext) {
        guard let url = audioURL else { return }
        guard autoSavedRecording == nil else { return } // Already auto-saved

        Logger.info("RecordingForm", "Auto-saving recording before transcription")

        // Create recording with notStarted status
        let recording = Recording(
            title: title.trimmed.isEmpty ? "Untitled recording" : title.trimmed,
            fileURL: url,
            fullText: "",
            language: "",
            notes: "",
            summary: nil,
            segments: [],
            collection: nil,
            recordedAt: Date(),
            transcriptionStatus: .notStarted,
            failureReason: nil,
            transcriptionStartedAt: nil
        )

        modelContext.insert(recording)

        do {
            try modelContext.save()
            autoSavedRecording = recording
            Logger.success("RecordingForm", "Recording auto-saved successfully")
        } catch {
            Logger.error("RecordingForm", "Failed to auto-save recording: \(error.localizedDescription)")
        }
    }

    /// Update the auto-saved recording when transcription starts
    @MainActor
    func markTranscriptionStarted(modelContext: ModelContext) {
        // If no auto-saved recording exists, create one first
        if autoSavedRecording == nil {
            autoSaveRecording(modelContext: modelContext)
        }

        // Now update the recording status - ensure it was created successfully
        guard let recording = autoSavedRecording else {
            Logger.warning("RecordingForm", "Could not mark transcription started - auto-save recording is nil")
            return
        }

        recording.status = .inProgress
        recording.transcriptionStartedAt = Date()

        do {
            try modelContext.save()
            Logger.success("RecordingForm", "Marked transcription as in progress")
        } catch {
            Logger.error("RecordingForm", "Failed to update recording status: \(error.localizedDescription)")
        }
    }

    /// Update the auto-saved recording with transcription results
    @MainActor
    private func updateAutoSavedRecording(_ recording: Recording, withTranscription: Bool, modelContext: ModelContext) {
        recording.title = title.trimmed.isEmpty ? "Untitled recording" : title.trimmed
        recording.fullText = transcribedText
        recording.language = transcribedLanguage
        recording.notes = note
        recording.collection = selectedCollection
        recording.status = .completed
        recording.failureReason = nil

        // Clear existing segments and add new ones
        recording.segments.removeAll()
        for segment in transcribedSegments {
            // CRITICAL: Insert segment into context if not already tracked
            if segment.modelContext == nil {
                modelContext.insert(segment)
            }
            recording.segments.append(segment)
        }

        Logger.success("RecordingForm", "Updated auto-saved recording - Title: \(recording.title), FullText length: \(recording.fullText.count), Segments: \(recording.segments.count), TranscribedText length: \(transcribedText.count)")
    }
    
    // MARK: - Save

    @MainActor
    func saveRecording(modelContext: ModelContext) -> Recording? {
        // If we have an auto-saved recording, just update metadata
        if let recording = autoSavedRecording {
            // Update metadata only - transcription continues in background
            recording.title = title.trimmed.isEmpty ? "Untitled recording" : title.trimmed
            recording.notes = note
            recording.collection = selectedCollection

            // Update transcription data if already completed
            if !isTranscribing && !transcribedText.isEmpty {
                recording.fullText = transcribedText
                recording.language = transcribedLanguage
                recording.status = .completed

                // Update segments
                recording.segments.removeAll()
                for segment in transcribedSegments {
                    if segment.modelContext == nil {
                        modelContext.insert(segment)
                    }
                    recording.segments.append(segment)
                }
            }

            do {
                try modelContext.save()
                Logger.success("RecordingForm", "Recording saved successfully")
                return recording
            } catch {
                Logger.error("RecordingForm", "Failed to save recording: \(error.localizedDescription)")
                return nil
            }
        }

        // Fallback: Create new recording if auto-save didn't happen
        guard let url = audioURL else { return nil }

        Logger.info("RecordingForm", "Saving recording with fullText length: \(transcribedText.count)")

        // Determine status based on transcription
        let status: TranscriptionStatus
        if isTranscribing {
            status = .inProgress
        } else if transcribedText.isEmpty {
            status = .notStarted
        } else {
            status = .completed
        }

        // Create recording first (without segments)
        let recording = Recording(
            title: title.trimmed.isEmpty ? "Untitled recording" : title.trimmed,
            fileURL: url,
            fullText: transcribedText,
            language: transcribedLanguage,
            notes: note,
            summary: nil,  // Summary will be generated when user clicks Summary tab
            segments: [],  // Start with empty array
            collection: selectedCollection,
            recordedAt: Date(),
            transcriptionStatus: status
        )

        // Insert the recording into the context
        modelContext.insert(recording)

        // Now add each segment to the recording AND insert into context
        for segment in transcribedSegments {
            modelContext.insert(segment)
            recording.segments.append(segment)
        }

        // Save the context to persist the recording
        do {
            try modelContext.save()
            Logger.success("RecordingForm", "Recording saved successfully")
            autoSavedRecording = recording
            return recording
        } catch {
            Logger.error("RecordingForm", "Failed to save recording: \(error.localizedDescription)")
            return nil
        }
    }
    
    func saveEdit() {
        guard let recording = existingRecording else { return }

        recording.title = title.trimmed.isEmpty ? "Untitled recording" : title.trimmed
        recording.collection = selectedCollection
        recording.notes = note
    }
    
    // MARK: - Cleanup
    
    func cleanupAudioFile() {
        if let url = audioURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    /// Clean up everything when user exits without saving
    @MainActor
    func cleanupOnExit(modelContext: ModelContext) {
        guard let recording = autoSavedRecording else {
            // No recording to clean up, just clean audio file
            cleanupAudioFile()
            return
        }

        let recordingId = recording.id
        Logger.info("RecordingForm", "Cleaning up recording on exit: \(recordingId.uuidString.prefix(8))")

        // CRITICAL: Cancel transcription and wait for cancellation to propagate
        // This prevents race condition where transcription completes after deletion
        TranscriptionProgressManager.shared.cancelTranscription(for: recordingId)

        // Wait briefly for cancellation to propagate through the system
        // This ensures the transcription task is cancelled before we delete the recording
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

            await MainActor.run {
                // Mark transcription as complete to clean up any remaining state
                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)

                // Clean up audio file first (before deleting recording)
                self.cleanupAudioFile()

                // Delete the recording from database
                modelContext.delete(recording)

                // Save the deletion immediately - this is critical
                do {
                    try modelContext.save()
                    Logger.success("RecordingForm", "Successfully deleted recording on exit: \(recordingId.uuidString.prefix(8))")
                } catch {
                    Logger.error("RecordingForm", "Failed to delete recording on exit: \(error.localizedDescription)")
                    // Try to save again - sometimes SwiftData needs a retry
                    do {
                        try modelContext.save()
                        Logger.success("RecordingForm", "Successfully deleted recording on retry")
                    } catch {
                        Logger.error("RecordingForm", "Failed to delete recording on retry: \(error.localizedDescription)")
                    }
                }

                // Clear the reference to prevent any further operations
                self.autoSavedRecording = nil
            }
        }
        
        // Reset transcription state
        isTranscribing = false
        transcriptionProgress = 0.0
    }
}
