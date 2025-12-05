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
    
    // MARK: - Computed Properties
    
    var isEditing: Bool {
        existingRecording != nil
    }
    
    var isFormValid: Bool {
        validateTitle() && validateNote()
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
                }
            } catch {
                await MainActor.run {
                    isTranscribing = false
                }
            }
        }
    }
    
    // MARK: - Save
    
    func saveRecording(modelContext: ModelContext, onComplete: () -> Void) {
        guard let url = audioURL else { return }
        
        // Create recording first (without segments)
        let recording = Recording(
            title: title.trimmed,
            fileURL: url,
            fullText: transcribedText,
            language: transcribedLanguage,
            notes: note,
            segments: [],  // Start with empty array
            collection: selectedCollection,
            recordedAt: Date()
        )
        
        // Insert the recording into the context
        modelContext.insert(recording)
        
        // Now add each segment to the recording AND insert into context
        for segment in transcribedSegments {
            modelContext.insert(segment)
            recording.segments.append(segment)
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
