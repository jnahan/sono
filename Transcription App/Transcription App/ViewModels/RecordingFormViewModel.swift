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
    
    // Validation state
    @Published var titleError: String? = nil
    @Published var noteError: String? = nil
    @Published var hasAttemptedSubmit = false
    
    // UI state
    @Published var showCollectionPicker = false
    @Published var showExitConfirmation = false
    
    // MARK: - Private Properties

    private let audioURL: URL?
    private let existingRecording: Recording?
    private var autoSavedRecording: Recording? = nil // Track auto-saved recording for recovery
    
    // MARK: - Computed Properties
    
    var isEditing: Bool {
        existingRecording != nil
    }
    
    var isFormValid: Bool {
        // For new recordings, ensure transcription is complete and has text
        if !isEditing {
            return validateTitle() && 
                   validateNote() && 
                   !isTranscribing && 
                   !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        // For editing, just validate title and note
        return validateTitle() && validateNote()
    }
    
    var saveButtonText: String {
        if isTranscribing && !isEditing {
            return "Processing recording"
        } else if isEditing {
            return "Save changes"
        } else {
            return "Save transcription"
        }
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
        guard let url = audioURL else { return }
        isTranscribing = true

        Task {
            do {
                // TranscriptionService will use settings from UserDefaults automatically
                let result = try await TranscriptionService.shared.transcribe(audioURL: url)

                await MainActor.run {
                    transcribedText = result.text
                    transcribedLanguage = result.language
                    transcribedSegments = result.segments.map { segment in
                        RecordingSegment(
                            start: segment.start,
                            end: segment.end,
                            text: segment.text
                        )
                    }
                    isTranscribing = false

                    // Update auto-saved recording if it exists
                    if let recording = autoSavedRecording {
                        updateAutoSavedRecording(recording, withTranscription: true)
                    }
                }
            } catch {
                await MainActor.run {
                    isTranscribing = false

                    // Mark auto-saved recording as failed
                    if let recording = autoSavedRecording {
                        recording.status = .failed
                        recording.failureReason = "Transcription failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    /// Auto-save a recording immediately after recording stops, before transcription
    func autoSaveRecording(modelContext: ModelContext) {
        guard let url = audioURL else { return }
        guard autoSavedRecording == nil else { return } // Already auto-saved

        print("💾 [RecordingForm] Auto-saving recording before transcription")

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

    /// Update the auto-saved recording when transcription starts
    func markTranscriptionStarted(modelContext: ModelContext) {
        guard let recording = autoSavedRecording else {
            autoSaveRecording(modelContext: modelContext)
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
    
    func saveRecording(modelContext: ModelContext, onComplete: () -> Void) {
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
