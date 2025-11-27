import SwiftUI
import SwiftData

struct FoldersView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query private var folders: [Folder]
    @Query private var recordings: [Recording]
    
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var searchText = ""
    
    private var filteredFolders: [Folder] {
        if searchText.isEmpty {
            return folders
        } else {
            return folders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                
                SearchBar(text: $searchText, placeholder: "Search...")
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                
                List {
                    ForEach(filteredFolders) { folder in
                        NavigationLink(value: folder) {
                            FolderRow(folder: folder, recordingCount: recordingCount(for: folder))
                        }
                    }
                    .onDelete(perform: deleteFolders)
                }
                .listStyle(.plain)
            }
            .navigationDestination(for: Folder.self) { folder in
                FolderDetailView(folder: folder, showPlusButton: showPlusButton)
                    .onAppear { showPlusButton.wrappedValue = false }
                    .onDisappear { showPlusButton.wrappedValue = true }  // Add this line
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
    
    private var headerView: some View {
        HStack {
            Text("Collections")
                .bold()
                .font(.custom("LibreBaskerville-Regular", size: 20))
            
            Spacer()
            
            Button {
                showCreateFolder = true
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 20))
                    .foregroundColor(.warmGray600)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
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
                modelContext.delete(filteredFolders[index])
            }
        }
    }
}

// MARK: - Folder Row Component
struct FolderRow: View {
    let folder: Folder
    let recordingCount: Int
    @State private var showMenu = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Folder Icon
            ZStack {
                Circle()
                    .fill(Color.accentLight)
                    .frame(width: 56, height: 56)
                
                Image(systemName: "waveform")
                    .font(.system(size: 20))
                    .foregroundColor(.accent)
            }
            
            // Folder Info
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.baseBlack)
                
                Text("\(recordingCount) recordings")
                    .font(.system(size: 14))
                    .foregroundColor(.warmGray500)
            }
            
            Spacer()
            
            // Three-dot menu
            Button {
                showMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundColor(.warmGray600)
                    .rotationEffect(.degrees(90))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Rename") {
                // Handle rename
            }
            
            Button("Delete", role: .destructive) {
                // Handle delete
            }
            
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct FolderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecordings: [Recording]
    
    @StateObject private var viewModel = RecordingListViewModel()
    
    let folder: Folder
    var showPlusButton: Binding<Bool>
    
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
                            player: viewModel.player,
                            onCopy: { viewModel.copyRecording(recording) },
                            onEdit: { viewModel.editRecording(recording) },
                            onDelete: { viewModel.deleteRecording(recording) }
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
            .toolbar(.hidden, for: .tabBar)
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
            
            if viewModel.showCopyToast {
                VStack {
                    CopyToast()
                    Spacer()
                }
                .padding(.top, 10)
            }
            
            if viewModel.editingRecording != nil {
                EditRecordingOverlay(
                    isPresented: Binding(
                        get: { viewModel.editingRecording != nil },
                        set: { if !$0 { viewModel.cancelEdit() } }
                    ),
                    newTitle: $viewModel.newRecordingTitle,
                    onSave: viewModel.saveEdit
                )
            }
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext)
        }
    }
}

#Preview {
    FoldersView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Folder.self], inMemory: true)
}
