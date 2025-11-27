import SwiftUI
import SwiftData

struct FoldersView: View {
    // MARK: - Environment & Queries
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query private var folders: [Folder]
    @Query private var recordings: [Recording]
    
    // MARK: - State
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    
    // MARK: - Body
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
                    emptyState
                }
            }
        }
        .onAppear {
            showPlusButton.wrappedValue = true
        }
    }
    
    // MARK: - Subviews
    private var emptyState: some View {
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
    
    // MARK: - Helper Methods
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

// MARK: - Folder Row
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

// MARK: - Folder Detail View
struct FolderDetailView: View {
    // MARK: - Environment & Queries
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecordings: [Recording]
    
    // MARK: - State Objects
    @StateObject private var player = MiniPlayer()
    
    // MARK: - Properties
    let folder: Folder
    var showPlusButton: Binding<Bool>
    
    // MARK: - State
    @State private var showCopyToast = false
    @State private var editingRecording: Recording?
    @State private var newRecordingTitle = ""
    
    // MARK: - Computed Properties
    private var recordings: [Recording] {
        allRecordings.filter { $0.folder?.id == folder.id }
    }
    
    // MARK: - Body
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
                    emptyState
                }
            }
            
            // Copy Toast
            if showCopyToast {
                toastView
            }
            
            // Edit Overlay
            if editingRecording != nil {
                editOverlay
            }
        }
    }
    
    // MARK: - Subviews
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Recordings", systemImage: "mic.slash")
        } description: {
            Text("This folder is empty")
        }
    }
    
    private var toastView: some View {
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
    
    private var editOverlay: some View {
        ZStack {
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
                        saveEdit()
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
    
    // MARK: - Helper Methods
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

// MARK: - Preview
#Preview {
    FoldersView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Folder.self], inMemory: true)
}
