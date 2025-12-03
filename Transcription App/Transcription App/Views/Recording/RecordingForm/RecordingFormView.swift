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
    
    @State private var title: String = ""
    @State private var selectedFolder: Folder? = nil
    @State private var note: String = ""
    @State private var transcriptionError: String? = nil
    @State private var transcribedText: String = ""
    @State private var transcribedLanguage: String = ""
    @State private var transcribedSegments: [RecordingSegment] = []
    @State private var showFolderPicker = false
    @State private var isTranscribing = false
    @Environment(\.dismiss) private var dismiss
    
    private var isEditing: Bool {
        existingRecording != nil
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
                    VStack(spacing: 8) {
                        Text("Transcribing audio")
                            .font(.custom("LibreBaskerville-Regular", size: 24))
                            .foregroundColor(.baseBlack)
                        
                        Text("Please do not close the app\nuntil transcription is complete")
                            .font(.system(size: 16))
                            .foregroundColor(.warmGray500)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)
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
                
                // Form fields
                VStack(spacing: 16) {
                    // Title field
                    VStack(alignment: .leading, spacing: 8) {
                        InputLabel(text: "Title")
                        InputField(text: $title, placeholder: "Title")
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
                            height: 200
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, isEditing ? 24 : 0)
                
                Spacer()
                
                // Save button
                Button {
                    if isEditing {
                        saveEdit()
                    } else {
                        saveRecording()
                    }
                } label: {
                    Text(isEditing ? "Save changes" : "Save transcription")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(title.isEmpty || isTranscribing ? Color.warmGray400 : Color.black)
                        .cornerRadius(16)
                }
                .disabled(title.isEmpty || isTranscribing)
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
        }
        .navigationBarHidden(true)
    }
    
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
