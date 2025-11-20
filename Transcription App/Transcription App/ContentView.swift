import SwiftUI
import SwiftData
import WhisperKit
import Combine
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var recordingObjects: [Recording]
    @StateObject private var player = MiniPlayer()
    
    @State private var searchText: String = ""
    @State private var filteredRecordings: [Recording] = []
    @State private var showCopyToast = false
    
    @State private var editingRecording: Recording? = nil
    @State private var newRecordingTitle: String = ""
    @State private var showSettings = false // <- Add this line
    
    @State private var selectedRecording: Recording? = nil
    
    private func updateFilteredRecordings() {
        if searchText.isEmpty {
            filteredRecordings = recordingObjects
        } else {
            filteredRecordings = recordingObjects.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.fullText.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            if showCopyToast {
                Text("Recording copied")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(1)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
            
            if let editing = editingRecording {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        editingRecording = nil
                    }

                VStack(spacing: 20) {
                    Text("Edit Recording Title")
                        .font(.headline)

                    TextField("New Title", text: $newRecordingTitle)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    HStack {
                        Button("Cancel") {
                            editingRecording = nil
                        }
                        .buttonStyle(.bordered)

                        Button("Save") {
                            if let index = recordingObjects.firstIndex(where: { $0.id == editing.id }) {
                                recordingObjects[index].title = newRecordingTitle
                            }
                            editingRecording = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .frame(maxWidth: 400)
                .shadow(radius: 20)
            }

            VStack(alignment: .leading, spacing: 20) {
                RecorderView(onFinishRecording: { url in
                    Task {
                        await addRecordingAndTranscribe(fileURL: url)
                    }
                })

                Text("My Recordings")
                    .font(.title)
                    .padding(.top)

                Button("Add Recording") {
                    Task {
                        await addRecordingAndTranscribe()
                    }
                }
                .buttonStyle(.borderedProminent)

                List(selection: $selectedRecording) {
                    ForEach(filteredRecordings) { recording in
                        HStack {
                            Text(recording.title)
                                .lineLimit(1)

                            Spacer()

                            Button {
                                if player.playingURL == recording.fileURL && player.isPlaying {
                                    player.pause()
                                } else {
                                    player.play(recording.fileURL)
                                }
                            } label: {
                                Image(systemName: (player.playingURL == recording.fileURL && player.isPlaying) ? "pause.fill" : "play.fill")
                            }
                            .buttonStyle(.plain)

                            ProgressView(value: player.playingURL == recording.fileURL ? player.progress : 0)
                                .frame(width: 60)

                            Menu {
                                Button {
                                    UIPasteboard.general.string = recording.fullText
                                    withAnimation { showCopyToast = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { showCopyToast = false }
                                    }
                                } label: {
                                    Label("Copy Transcription", systemImage: "doc.on.doc")
                                }

                                Button {
                                    let activityVC = UIActivityViewController(activityItems: [recording.fullText], applicationActivities: nil)
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let rootVC = windowScene.keyWindow?.rootViewController {
                                        rootVC.present(activityVC, animated: true)
                                    }
                                } label: {
                                    Label("Share Transcription", systemImage: "square.and.arrow.up")
                                }

                                Button {
                                    let activityVC = UIActivityViewController(activityItems: [recording.fileURL], applicationActivities: nil)
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let rootVC = windowScene.keyWindow?.rootViewController {
                                        rootVC.present(activityVC, animated: true)
                                    }
                                } label: {
                                    Label("Export Audio", systemImage: "square.and.arrow.up.fill")
                                }

                                Button {
                                    editingRecording = recording
                                    newRecordingTitle = recording.title
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    if let index = recordingObjects.firstIndex(where: { $0.id == recording.id }) {
                                        modelContext.delete(recordingObjects[index])
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                            } label: {
                                Image(systemName: "ellipsis")
                                    .rotationEffect(.degrees(90))
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .menuStyle(.borderlessButton)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRecording = recording
                        }
                    }
                    .onDelete(perform: deleteRecordings)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                    // Add Settings Button
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .padding()
            .searchable(text: $searchText, prompt: "Search recordings")
            .onChange(of: searchText) { _ in updateFilteredRecordings() }
            .onChange(of: recordingObjects) { _ in updateFilteredRecordings() }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }

        } detail: {
            if let selected = selectedRecording {
                RecordingDetailView(recording: selected)
            } else {
                Text("Select a recording")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    private func deleteRecordings(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(recordingObjects[index])
            }
        }
    }

    private func addRecordingAndTranscribe(fileURL: URL? = nil, filePath: String? = nil) async {
        let audioURL: URL
        if let fileURL {
            audioURL = fileURL
        } else if let filePath {
            audioURL = URL(fileURLWithPath: filePath)
        } else {
            guard let sampleURL = Bundle.main.url(forResource: "jfk", withExtension: "wav") else {
                print("Audio file not found!")
                return
            }
            audioURL = sampleURL
        }

        do {
            let pipe = try await WhisperKit(WhisperKitConfig(model: "tiny"))
            let results = try await pipe.transcribe(audioPath: audioURL.path)

            guard let firstResult = results.first else { return }

            let segments = firstResult.segments.map { seg in
                RecordingSegment(
                    start: Double(seg.start),
                    end: Double(seg.end),
                    text: seg.text
                )
            }

            let recording = Recording(
                title: audioURL.lastPathComponent,
                fileURL: audioURL,
                filePath: audioURL.path,
                fullText: firstResult.text,
                language: firstResult.language,
                segments: segments,
                recordedAt: Date()
            )

            modelContext.insert(recording)

        } catch {
            print("Transcription failed:", error)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Recording.self, RecordingSegment.self], inMemory: true)
}
