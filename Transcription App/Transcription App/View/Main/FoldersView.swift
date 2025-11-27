import SwiftUI
import SwiftData

struct FoldersView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query private var folders: [Folder]
    @Query private var recordings: [Recording]
    
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var selectedFolder: Folder?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(folders) { folder in
                    NavigationLink(value: folder) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(folder.name)
                                    .font(.headline)
                                
                                Text("\(recordingCount(for: folder)) recordings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteFolders)
            }
            .navigationTitle("Folders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateFolder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .navigationDestination(for: Folder.self) { folder in
                FolderDetailView(folder: folder, showPlusButton: showPlusButton)
                    .onAppear { showPlusButton.wrappedValue = false }
            }
            .alert("Create Folder", isPresented: $showCreateFolder) {
                TextField("Folder name", text: $newFolderName)
                Button("Cancel", role: .cancel) {
                    newFolderName = ""
                }
                Button("Create") {
                    createFolder()
                }
            }
            .overlay {
                if folders.isEmpty {
                    ContentUnavailableView {
                        Label("No Folders", systemImage: "folder")
                    } description: {
                        Text("Create a folder to organize your recordings")
                    } actions: {
                        Button("Create Folder") {
                            showCreateFolder = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .onAppear {
            showPlusButton.wrappedValue = true
        }
    }
    
    private func recordingCount(for folder: Folder) -> Int {
        recordings.filter { $0.folder?.id == folder.id }.count
    }
    
    private func createFolder() {
        guard !newFolderName.isEmpty else { return }
        
        let folder = Folder(name: newFolderName)
        modelContext.insert(folder)
        
        newFolderName = ""
    }
    
    private func deleteFolders(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(folders[index])
            }
        }
    }
}

// MARK: - Folder Detail View
struct FolderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecordings: [Recording]
    @StateObject private var player = MiniPlayer()
    
    let folder: Folder
    var showPlusButton: Binding<Bool>
    
    @State private var showCopyToast = false
    @State private var editingRecording: Recording?
    @State private var newRecordingTitle = ""
    
    private var recordings: [Recording] {
        allRecordings.filter { $0.folder?.id == folder.id }
    }
    
    var body: some View {
        ZStack {
            List {
                ForEach(recordings) { recording in
                    NavigationLink(value: recording) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recording.title)
                                    .lineLimit(1)
                                
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
                                    modelContext.delete(recording)
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
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(recordings[index])
                    }
                }
            }
            .navigationTitle(folder.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Recording.self) { recording in
                RecordingDetailView(recording: recording)
                    .onAppear { showPlusButton.wrappedValue = false }
            }
            .overlay {
                if recordings.isEmpty {
                    ContentUnavailableView {
                        Label("No Recordings", systemImage: "mic.slash")
                    } description: {
                        Text("This folder is empty")
                    }
                }
            }
            
            if showCopyToast {
                VStack {
                    Text("Recording copied")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    Spacer()
                }
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
                            editing.title = newRecordingTitle
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
    }
}

#Preview {
    FoldersView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Folder.self], inMemory: true)
}
