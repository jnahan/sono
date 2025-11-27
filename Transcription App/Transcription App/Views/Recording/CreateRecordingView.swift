import SwiftUI
import SwiftData
import Foundation

struct CreateRecordingView: View {
    @Binding var isPresented: Bool
    let audioURL: URL
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $title)
                }
                
                Section("Folder") {
                    Button {
                        showFolderPicker = true
                    } label: {
                        HStack {
                            Text(selectedFolder?.name ?? "Choose folder")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                
                Section("Note") {
                    TextEditor(text: $note)
                        .frame(height: 200)
                }
                
                if isTranscribing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Transcribing...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let error = transcriptionError {
                    Section {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button("Save transcription") {
                        saveRecording()
                    }
                    .disabled(title.isEmpty || isTranscribing)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("New Recording")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
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
                title = audioURL.deletingPathExtension().lastPathComponent
                startTranscription()
            }
        }
    }
    
    private func startTranscription() {
        isTranscribing = true
        transcriptionError = nil
        
        Task {
            do {
                let result = try await TranscriptionService.shared.transcribe(audioURL: audioURL)
                
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
        let recording = Recording(
            title: title,
            fileURL: audioURL,
            filePath: audioURL.path,
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
}

struct FolderPickerView: View {
    let folders: [Folder]
    @Binding var selectedFolder: Folder?
    let modelContext: ModelContext
    @Binding var isPresented: Bool
    
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    Button {
                        showCreateFolder = true
                    } label: {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("Create folder")
                        }
                    }
                    
                    ForEach(folders) { folder in
                        Button {
                            selectedFolder = folder
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                Text(folder.name)
                                Spacer()
                                if selectedFolder?.id == folder.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Choose a folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .alert("Create Folder", isPresented: $showCreateFolder) {
                TextField("Folder name", text: $newFolderName)
                Button("Cancel", role: .cancel) {
                    newFolderName = ""
                }
                Button("Create") {
                    if !newFolderName.isEmpty {
                        let newFolder = Folder(name: newFolderName)
                        modelContext.insert(newFolder)
                        selectedFolder = newFolder
                        newFolderName = ""
                    }
                }
            }
        }
    }
}
