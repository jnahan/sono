import SwiftUI
import SwiftData
import Foundation
import WhisperKit

struct TranscriptionDetailView: View {
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
                    .disabled(title.isEmpty)
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
                print("=== TranscriptionDetailView APPEARED ===")
                print("Audio URL: \(audioURL)")
                print("Audio path: \(audioURL.path)")
                print("File exists: \(FileManager.default.fileExists(atPath: audioURL.path))")
                title = audioURL.deletingPathExtension().lastPathComponent
                print("Title set to: \(title)")
                startTranscription()
            }
        }
    }
    
    private func startTranscription() {
        print("=== STARTING TRANSCRIPTION ===")
        Task {
            do {
                print("Creating WhisperKit with tiny model...")
                let pipe = try await WhisperKit(WhisperKitConfig(model: "tiny"))
                print("Transcribing audio at: \(audioURL.path)")
                let results = try await pipe.transcribe(audioPath: audioURL.path)
                print("Got \(results.count) results")
                
                if let firstResult = results.first {
                    let segments = firstResult.segments.map { seg in
                        RecordingSegment(
                            start: Double(seg.start),
                            end: Double(seg.end),
                            text: seg.text
                        )
                    }
                    
                    await MainActor.run {
                        print("=== TRANSCRIPTION COMPLETE ===")
                        print("Text length: \(firstResult.text.count) characters")
                        print("First 100 chars: \(String(firstResult.text.prefix(100)))")
                        transcribedText = firstResult.text
                        transcribedLanguage = firstResult.language
                        transcribedSegments = segments
                    }
                } else {
                    await MainActor.run {
                        print("=== NO TRANSCRIPTION RESULTS ===")
                        transcriptionError = "No transcription results returned"
                    }
                }
            } catch {
                print("=== TRANSCRIPTION FAILED ===")
                print("Error: \(error)")
                print("Error details: \(error.localizedDescription)")
                await MainActor.run {
                    transcriptionError = error.localizedDescription
                }
            }
        }
    }
    
    private func saveRecording() {
        print("=== SAVING RECORDING ===")
        print("Title: \(title)")
        print("Text length: \(transcribedText.count)")
        print("Folder: \(selectedFolder?.name ?? "none")")
        
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

// MARK: - Folder Picker View
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
