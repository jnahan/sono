import SwiftUI
import SwiftData
import WhisperKit
import Combine
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query private var recordingObjects: [Recording]
    @Query private var folders: [Folder]
    @StateObject private var player = MiniPlayer()
    
    @State private var searchText: String = ""
    @State private var filteredRecordings: [Recording] = []
    @State private var showCopyToast = false
    
    @State private var editingRecording: Recording? = nil
    @State private var newRecordingTitle: String = ""
    @State private var showSettings = false
    
    @State private var selectedRecording: Recording? = nil
    
    // Navigation to recorder screen
    @State private var showRecorderScreen = false
    
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
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
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
                    
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("My Recordings")
                                .font(.largeTitle)
                                .bold()
                            
                            Spacer()
                            
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gear")
                                    .font(.title3)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        Button {
                            showRecorderScreen = true
                        } label: {
                            Label("Record Audio", systemImage: "mic.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                        
                        List {
                            ForEach(filteredRecordings) { recording in
                                Button {
                                    selectedRecording = recording
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(recording.title)
                                                .lineLimit(1)
                                                .foregroundColor(.primary)
                                            
                                            Text(recording.recordedAt, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            if player.playingURL == recording.resolvedURL && player.isPlaying {
                                                player.pause()
                                            } else if let url = recording.resolvedURL {
                                                player.play(url)
                                            }
                                        } label: {
                                            Image(systemName: (player.playingURL == recording.resolvedURL && player.isPlaying) ? "pause.fill" : "play.fill")
                                        }
                                        .buttonStyle(.plain)
                                        
                                        ProgressView(value: player.playingURL == recording.resolvedURL ? player.progress : 0)
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
                                                if let url = recording.resolvedURL {
                                                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                                       let rootVC = windowScene.keyWindow?.rootViewController {
                                                        rootVC.present(activityVC, animated: true)
                                                    }
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
                                }
                            }
                            .onDelete(perform: deleteRecordings)
                        }
                        .listStyle(.plain)
                    }
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
            }
            .searchable(text: $searchText, prompt: "Search recordings")
            .onChange(of: searchText) { _ in updateFilteredRecordings() }
            .onChange(of: recordingObjects) { _ in updateFilteredRecordings() }
            .onAppear {
                updateFilteredRecordings()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(item: $selectedRecording) { recording in
                RecordingDetailView(recording: recording)
                    .onAppear { showPlusButton.wrappedValue = false }
                    .onDisappear { showPlusButton.wrappedValue = true }
            }
        }
        .fullScreenCover(isPresented: $showRecorderScreen) {
            RecorderScreen()
        }
    }

    private func deleteRecordings(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(recordingObjects[index])
            }
        }
    }
}

// MARK: - URL Identifiable Extension
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

#Preview {
    ContentView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Folder.self], inMemory: true)
}
