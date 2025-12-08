import SwiftUI
import SwiftData
import Foundation

/// ViewModel for RecordingFormView handling validation and business logic
class RecordingFormViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Form state
    @Published var title: String = ""
    @Published var selectedCollection: Collection? = nil
    @Published var note: String = ""
    
    // Transcription state
    @Published var transcribedText: String = ""
    @Published var transcribedLanguage: String = ""
    @Published var transcribedSegments: [RecordingSegment] = []
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0.0 // 0.0 to 1.0
    @Published var isModelLoading = false // Track if model is being downloaded/loaded
    @Published var isModelWarming = false // Track if model is warming up
    
    // Validation state
    @Published var titleError: String? = nil
    @Published var noteError: String? = nil
    @Published var hasAttemptedSubmit = false
    
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
    
    var isFormValid: Bool {
        // For new recordings, ensure transcription is complete (can be empty if silent)
        if !isEditing {
            return validateTitle() && 
                   validateNote() && 
                   !isTranscribing && 
                   !isModelLoading &&
                   !isModelWarming
        }
        // For editing, just validate title and note
        return validateTitle() && validateNote()
    }
    
    var saveButtonText: String {
        if isEditing {
            return "Save changes"
        }
        
        // For new recordings, NEVER show "Save transcription" until transcription is complete
        if isModelLoading {
            return "Downloading model..."
        }
        
        if isModelWarming {
            return "Warming up model..."
        }
        
        if isTranscribing {
            return "Transcribing audio \(Int(transcriptionProgress * 100))%"
        }
        
        // If transcription is NOT in progress and NOT loading/warming, it's complete
        // (even if empty - user may have been silent)
        if !isTranscribing && !isModelLoading && !isModelWarming {
            return "Save transcription"
        }
        
        // Otherwise, we're still waiting
        return "Preparing..."
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
            note = recording.notes ?? ""
            transcribedText = recording.fullText
            transcribedLanguage = recording.language
        } else if let url = audioURL {
            // New recording
            title = url.deletingPathExtension().lastPathComponent
        }
    }
    
    func startTranscriptionIfNeeded() {
        if existingRecording == nil, audioURL != nil {
            startTranscription()
        }
    }
    
    // MARK: - Validation
    
    func validateTitle() -> Bool {
        let trimmed = title.trimmed
        return !trimmed.isEmpty && trimmed.count <= AppConstants.Validation.maxTitleLength
    }
    
    func validateNote() -> Bool {
        return note.count <= AppConstants.Validation.maxNoteLength
    }
    
    @discardableResult
    func validateTitleWithError() -> Bool {
        if hasAttemptedSubmit {
            let trimmed = title.trimmed
            
            // Validate not empty
            if let error = ValidationHelper.validateNotEmpty(trimmed, fieldName: "Title") {
                titleError = error
                return false
            }
            
            // Validate length
            if let error = ValidationHelper.validateLength(trimmed, max: AppConstants.Validation.maxTitleLength, fieldName: "Title") {
                titleError = error
                return false
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
            if let error = ValidationHelper.validateLength(note, max: AppConstants.Validation.maxNoteLength, fieldName: "Note") {
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

    private func startTranscription() {
        guard let url = audioURL else {
            showError("Audio file not found")
            return
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
                        showError("Transcription model failed to load. Please restart the app.")
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
            do {
                print("🎯 [RecordingForm] Starting transcription for: \(url.lastPathComponent)")
                let result = try await TranscriptionService.shared.transcribe(audioURL: url) { progress in
                    Task { @MainActor in
                        self.transcriptionProgress = progress
                    }
                }
                print("✅ [RecordingForm] Transcription completed successfully")
                handleTranscriptionResult(result)
            } catch {
                print("❌ [RecordingForm] Transcription error: \(error)")
                print("   Error type: \(type(of: error))")
                print("   Error description: \(error.localizedDescription)")
                handleTranscriptionError(error)
            }
        }
    }
    
    @MainActor
    private func handleTranscriptionResult(_ result: TranscriptionResult) {
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

        // Update auto-saved recording if it exists
        if let recording = autoSavedRecording {
            updateAutoSavedRecording(recording, withTranscription: true)
        }
        
        // If transcription is empty, it's still complete (might be very short recording)
        // Don't show error - just allow user to save with empty transcription
    }
    
    @MainActor
    private func handleTranscriptionError(_ error: Error) {
        isTranscribing = false
        isModelLoading = false
        isModelWarming = false
        transcriptionProgress = 0.0
        showError("Transcription failed: \(error.localizedDescription)")

        // Mark auto-saved recording as failed
        if let recording = autoSavedRecording {
            recording.status = .failed
            recording.failureReason = "Transcription failed: \(error.localizedDescription)"
        }
    }
    
    func showError(_ message: String) {
        Task { @MainActor in
            errorMessage = message
            withAnimation {
                showErrorToast = true
            }
        }
    }

    /// Auto-save a recording immediately after recording stops, before transcription
    func autoSaveRecording(modelContext: ModelContext) {
        guard let url = audioURL else { return }
        guard autoSavedRecording == nil else { return } // Already auto-saved

        print("💾 [RecordingForm] Auto-saving recording before transcription")

        // Perform save operation asynchronously to avoid blocking main thread
        Task { @MainActor in
            // Create recording with notStarted status
            let recording = Recording(
                title: title.trimmed.isEmpty ? url.deletingPathExtension().lastPathComponent : title.trimmed,
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
                print("✅ [RecordingForm] Recording auto-saved successfully")
            } catch {
                print("❌ [RecordingForm] Failed to auto-save recording: \(error)")
            }
        }
    }

    /// Update the auto-saved recording when transcription starts
    func markTranscriptionStarted(modelContext: ModelContext) {
        // Perform save operation asynchronously to avoid blocking main thread
        Task { @MainActor in
            guard let recording = autoSavedRecording else {
                autoSaveRecording(modelContext: modelContext)
                // Wait a bit for auto-save to complete
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                guard let recording = autoSavedRecording else { return }
                recording.status = .inProgress
                recording.transcriptionStartedAt = Date()
                try? modelContext.save()
                return
            }

            recording.status = .inProgress
            recording.transcriptionStartedAt = Date()

            do {
                try modelContext.save()
                print("✅ [RecordingForm] Marked transcription as in progress")
            } catch {
                print("❌ [RecordingForm] Failed to update recording status: \(error)")
            }
        }
    }

    /// Update the auto-saved recording with transcription results
    private func updateAutoSavedRecording(_ recording: Recording, withTranscription: Bool) {
        recording.title = title.trimmed
        recording.fullText = transcribedText
        recording.language = transcribedLanguage
        recording.notes = note
        recording.collection = selectedCollection
        recording.status = .completed
        recording.failureReason = nil

        // Clear existing segments and add new ones
        recording.segments.removeAll()
        for segment in transcribedSegments {
            recording.segments.append(segment)
        }

        print("✅ [RecordingForm] Updated auto-saved recording with transcription")
    }
    
    // MARK: - Save
    
    func saveRecording(modelContext: ModelContext, onComplete: @escaping () -> Void) {
        // Perform save operation asynchronously to avoid blocking main thread
        Task { @MainActor in
            // If we have an auto-saved recording, just update it
            if let recording = autoSavedRecording {
                updateAutoSavedRecording(recording, withTranscription: !transcribedText.isEmpty)

                // Add segments to context if transcription completed
                if !transcribedText.isEmpty {
                    for segment in transcribedSegments {
                        if segment.modelContext == nil {
                            modelContext.insert(segment)
                        }
                    }
                }

                do {
                    try modelContext.save()
                    print("✅ [RecordingForm] Recording saved successfully")
                } catch {
                    print("❌ [RecordingForm] Failed to save recording: \(error)")
                }

                onComplete()
                return
            }

            // Fallback: Create new recording if auto-save didn't happen
            guard let url = audioURL else { return }

            print("💾 [RecordingForm] Saving recording with fullText length: \(transcribedText.count)")

            // Determine status based on transcription
            let status: TranscriptionStatus
            if transcribedText.isEmpty {
                status = .notStarted
            } else if isTranscribing {
                status = .inProgress
            } else {
                status = .completed
            }

            // Create recording first (without segments)
            let recording = Recording(
                title: title.trimmed,
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
                print("✅ [RecordingForm] Recording saved successfully")
            } catch {
                print("❌ [RecordingForm] Failed to save recording: \(error)")
            }

            onComplete()
        }
    }
    
    func saveEdit() {
        guard let recording = existingRecording else { return }
        
        recording.title = title.trimmed
        recording.collection = selectedCollection
        recording.notes = note
    }
    
    // MARK: - Cleanup
    
    func cleanupAudioFile() {
        if let url = audioURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
