import SwiftUI
import SwiftData

struct FoldersView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query private var folders: [Folder]
    @Query private var recordings: [Recording]
    
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(folders) { folder in
                    NavigationLink(value: folder) {
                        FolderRow(folder: folder, recordingCount: recordingCount(for: folder))
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
                    EmptyStateView(
                        icon: "folder",
                        title: "No Folders",
                        description: "Create a folder to organize your recordings",
                        actionTitle: "Create Folder",
                        action: { showCreateFolder = true }
                    )
                }
            }
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

private struct FolderRow: View {
    let folder: Folder
    let recordingCount: Int
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.headline)
                
                Text("\(recordingCount) recordings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FolderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecordings: [Recording]
    
    @StateObject private var player = Player()
    
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
                        RecordingRow(
                            recording: recording,
                            player: player,
                            onCopy: { copyRecording(recording) },
                            onEdit: { editRecording(recording) },
                            onDelete: { deleteRecording(recording) }
                        )
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
                RecordingDetailsView(recording: recording)
                    .onAppear { showPlusButton.wrappedValue = false }
            }
            .overlay {
                if recordings.isEmpty {
                    EmptyStateView(
                        icon: "mic.slash",
                        title: "No Recordings",
                        description: "This folder is empty",
                        actionTitle: nil,
                        action: nil
                    )
                }
            }
            
            if showCopyToast {
                VStack {
                    CopyToast()
                    Spacer()
                }
                .padding(.top, 10)
            }
            
            if editingRecording != nil {
                EditRecordingOverlay(
                    isPresented: Binding(
                        get: { editingRecording != nil },
                        set: { if !$0 { editingRecording = nil } }
                    ),
                    newTitle: $newRecordingTitle,
                    onSave: saveEdit
                )
            }
        }
    }
    
    private func copyRecording(_ recording: Recording) {
        UIPasteboard.general.string = recording.fullText
        withAnimation { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopyToast = false }
        }
    }
    
    private func editRecording(_ recording: Recording) {
        editingRecording = recording
        newRecordingTitle = recording.title
    }
    
    private func deleteRecording(_ recording: Recording) {
        modelContext.delete(recording)
    }
    
    private func saveEdit() {
        guard let editing = editingRecording else { return }
        editing.title = newRecordingTitle
        editingRecording = nil
    }
}

#Preview {
    FoldersView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Folder.self], inMemory: true)
}
