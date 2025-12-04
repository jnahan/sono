import SwiftUI
import SwiftData
import Foundation

struct RecordingFormView: View {
    @Binding var isPresented: Bool
    let audioURL: URL?
    let existingRecording: Recording?
    let folders: [Folder]
    let modelContext: ModelContext
    let onTranscriptionComplete: () -> Void
    let onExit: (() -> Void)?
    
    @State private var title: String = ""
    @State private var selectedFolder: Folder? = nil
    @State private var note: String = ""
    @State private var transcriptionError: String? = nil
    @State private var transcribedText: String = ""
    @State private var transcribedLanguage: String = ""
    @State private var transcribedSegments: [RecordingSegment] = []
    @State private var showFolderPicker = false
    @State private var isTranscribing = false
    @State private var showExitConfirmation = false
    
    // Validation state
    @State private var titleError: String? = nil
    @State private var noteError: String? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    // Validation constants
    private let maxTitleLength = 50
    private let maxNoteLength = 200
    
    private var isEditing: Bool {
        existingRecording != nil
    }
    
    private var isFormValid: Bool {
        validateTitle() && validateNote()
    }
    
    private var saveButtonText: String {
        if isEditing {
            return "Save changes"
        } else {
            return "Save transcription"
        }
    }
    
    var body: some View {
        ZStack {
            Color.warmGray50
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                if isEditing {
                    CustomTopBar(
                        title: "Edit Recording",
                        leftIcon: "caret-left",
                        onLeftTap: {
                            isPresented = false
                            dismiss()
                        }
                    )
                    .padding(.top, 12)
                } else {
                    CustomTopBar(
                        title: "New recording",
                        leftIcon: "x",
                        onLeftTap: {
                            showExitConfirmation = true
                        }
                    )
                    .padding(.top, 12)
                    
                    VStack(spacing: 8) {
                        Text("Transcribing audio")
                            .font(.custom("LibreBaskerville-Regular", size: 24))
                            .foregroundColor(.baseBlack)
                        
                        Text("Please do not close the app\nuntil transcription is complete")
                            .font(.system(size: 16))
                            .foregroundColor(.warmGray500)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                
                // Waveform animation (only for new recordings)
                if isTranscribing && !isEditing {
                    HStack(spacing: 4) {
                        ForEach(0..<20) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accent)
                                .frame(width: 3, height: CGFloat.random(in: 20...60))
                        }
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accent)
                            .padding(.leading, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                
                ScrollView {
                    // Form fields
                    VStack(spacing: 24) {
                        // Title field
                        VStack(alignment: .leading, spacing: 8) {
                            InputLabel(text: "Title")
                            InputField(
                                text: $title,
                                placeholder: "Title",
                                error: titleError
                            )
                            .onChange(of: title) { oldValue, newValue in
                                validateTitleWithError()
                            }
                        }
                        
                        // Folder field
                        VStack(alignment: .leading, spacing: 8) {
                            InputLabel(text: "Folder")
                            InputField(
                                text: Binding(
                                    get: { selectedFolder?.name ?? "" },
                                    set: { _ in }
                                ),
                                placeholder: "Select folder",
                                showChevron: true,
                                onTap: { showFolderPicker = true }
                            )
                        }
                        
                        // Note field
                        VStack(alignment: .leading, spacing: 8) {
                            InputLabel(text: "Note")
                            InputField(
                                text: $note,
                                placeholder: "Write a note for yourself...",
                                isMultiline: true,
                                height: 200,
                                error: noteError
                            )
                            .onChange(of: note) { oldValue, newValue in
                                validateNoteWithError()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, isEditing ? 24 : 0)
                }
                
                Spacer()
                
                // Save button
                Button {
                    if isFormValid {
                        if isEditing {
                            saveEdit()
                        } else {
                            saveRecording()
                        }
                    }
                } label: {
                    Text(saveButtonText)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background((isTranscribing || !isFormValid) ? Color.warmGray400 : Color.black)
                        .cornerRadius(16)
                }
                .disabled(isTranscribing || !isFormValid)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView(
                folders: folders,
                selectedFolder: $selectedFolder,
                modelContext: modelContext,
                isPresented: $showFolderPicker
            )
        }
        .sheet(isPresented: $showExitConfirmation) {
            ConfirmationSheet(
                isPresented: $showExitConfirmation,
                title: "Discard recording?",
                message: "Your recording will be lost if you exit now. Are you sure you want to continue?",
                confirmButtonText: "Discard recording",
                cancelButtonText: "Continue editing",
                onConfirm: {
                    // Delete the audio file if it exists
                    if let url = audioURL {
                        try? FileManager.default.removeItem(at: url)
                    }
                    isPresented = false
                    onExit?()
                }
            )
        }
        .onAppear {
            if let recording = existingRecording {
                // Pre-populate for editing
                title = recording.title
                selectedFolder = recording.folder
                note = recording.notes ?? ""
                transcribedText = recording.fullText
                transcribedLanguage = recording.language
            } else if let url = audioURL {
                // New recording
                title = url.deletingPathExtension().lastPathComponent
                startTranscription()
            }
            
            // Validate immediately on appear
            validateTitleWithError()
            validateNoteWithError()
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Validation Functions
    
    private func validateTitle() -> Bool {
        return !title.isEmpty && title.count <= maxTitleLength
    }
    
    private func validateNote() -> Bool {
        return note.count <= maxNoteLength
    }
    
    @discardableResult
    private func validateTitleWithError() -> Bool {
        if title.isEmpty {
            titleError = "Title is required"
            return false
        } else if title.count > maxTitleLength {
            titleError = "Title must be less than \(maxTitleLength) characters"
            return false
        } else {
            titleError = nil
            return true
        }
    }
    
    @discardableResult
    private func validateNoteWithError() -> Bool {
        if note.count > maxNoteLength {
            noteError = "Note must be less than \(maxNoteLength) characters"
            return false
        } else {
            noteError = nil
            return true
        }
    }
    
    // MARK: - Transcription
    
    private func startTranscription() {
        guard let url = audioURL else { return }
        isTranscribing = true
        transcriptionError = nil
        
        Task {
            do {
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
                    transcriptionError = error.localizedDescription
                    isTranscribing = false
                }
            }
        }
    }
    
    // MARK: - Save Functions
    
    private func saveRecording() {
        guard let url = audioURL else { return }
        
        let recording = Recording(
            title: title,
            fileURL: url,
            fullText: transcribedText,
            language: transcribedLanguage,
            notes: note,
            segments: transcribedSegments,
            folder: selectedFolder,
            recordedAt: Date()
        )
        
        modelContext.insert(recording)
        
        onTranscriptionComplete()
        isPresented = false
    }
    
    private func saveEdit() {
        guard let recording = existingRecording else { return }
        
        recording.title = title
        recording.folder = selectedFolder
        recording.notes = note
        
        isPresented = false
        dismiss()
    }
}
