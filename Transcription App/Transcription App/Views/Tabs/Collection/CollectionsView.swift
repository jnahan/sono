import SwiftUI
import SwiftData

struct CollectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query private var folders: [Folder]
    @Query private var recordings: [Recording]
    
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var searchText = ""
    @State private var selectedFolder: Folder?
    @State private var showSettings = false
    @State private var editingFolder: Folder?
    @State private var editFolderName = ""
    @State private var deletingFolder: Folder?
    
    private var filteredFolders: [Folder] {
        if searchText.isEmpty {
            return folders
        } else {
            return folders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient at absolute top of screen (when empty)
                if folders.isEmpty {
                    VStack(spacing: 0) {
                        Image("radial-gradient")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 280)
                            .frame(maxWidth: .infinity)
                            .rotationEffect(.degrees(180))
                            .clipped()
                        
                        Spacer()
                    }
                    .ignoresSafeArea(edges: .top)
                }
                
                VStack(spacing: 0) {
                    CustomTopBar(
                        title: "Collections",
                        rightIcon: "folder-plus",
                        onRightTap: { showCreateFolder = true }
                    )
                    
                    if !folders.isEmpty {
                        SearchBar(text: $searchText, placeholder: "Search collections...")
                            .padding(.horizontal, 20)
                    }
                    
                    if folders.isEmpty {
                        CollectionsEmptyState(showCreateFolder: $showCreateFolder)
                    } else {
                        List {
                            ForEach(filteredFolders) { folder in
                                Button {
                                    selectedFolder = folder
                                } label: {
                                    CollectionsRow(
                                        folder: folder,
                                        recordingCount: recordingCount(for: folder),
                                        onRename: {
                                            editingFolder = folder
                                            editFolderName = folder.name
                                        },
                                        onDelete: {
                                            deletingFolder = folder
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.warmGray50)
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            }
                            .onDelete(perform: deleteFolders)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.warmGray50)
                    }
                }
            }
            .background(Color.warmGray50.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedFolder) { folder in
                CollectionDetailView(folder: folder, showPlusButton: showPlusButton)
                    .onAppear { showPlusButton.wrappedValue = false }
                    .onDisappear { showPlusButton.wrappedValue = true }
            }
            .sheet(isPresented: $showCreateFolder) {
                CollectionFormSheet(
                    isPresented: $showCreateFolder,
                    folderName: $newFolderName,
                    isEditing: false,
                    onSave: createFolder,
                    existingFolders: folders,
                    currentFolder: nil
                )
            }

            .sheet(isPresented: Binding(
                get: { editingFolder != nil },
                set: { if !$0 { editingFolder = nil } }
            )) {
                CollectionFormSheet(
                    isPresented: Binding(
                        get: { editingFolder != nil },
                        set: { if !$0 { editingFolder = nil } }
                    ),
                    folderName: $editFolderName,
                    isEditing: true,
                    onSave: {
                        editingFolder?.name = editFolderName
                        editingFolder = nil
                    },
                    existingFolders: folders,
                    currentFolder: editingFolder
                )
            }
            .sheet(isPresented: Binding(
                get: { deletingFolder != nil },
                set: { if !$0 { deletingFolder = nil } }
            )) {
                if let folder = deletingFolder {
                    let folderRecordingCount = recordings.filter { $0.folder?.id == folder.id }.count
                    ConfirmationSheet(
                        isPresented: Binding(
                            get: { deletingFolder != nil },
                            set: { if !$0 { deletingFolder = nil } }
                        ),
                        title: "Delete folder?",
                        message: "Are you sure you want to delete \"\(folder.name)\"? This will remove all \(folderRecordingCount) recording\(folderRecordingCount == 1 ? "" : "s") in this collection.",
                        confirmButtonText: "Delete folder",
                        cancelButtonText: "Cancel",
                        onConfirm: {
                            // Delete all recordings in this folder
                            let recordingsInFolder = recordings.filter { $0.folder?.id == folder.id }
                            for recording in recordingsInFolder {
                                modelContext.delete(recording)
                            }
                            
                            // Now delete the folder
                            modelContext.delete(folder)
                            deletingFolder = nil
                        }
                    )
                }
            }
        }
    }
    
    private func recordingCount(for folder: Folder) -> Int {
        recordings.filter { $0.folder?.id == folder.id }.count
    }
    
    private func deleteFolders(offsets: IndexSet) {
        // Get the first folder from offsets and show confirmation
        if let index = offsets.first {
            deletingFolder = filteredFolders[index]
        }
    }
    
    private func createFolder() {
        guard !newFolderName.isEmpty else { return }
        
        let folder = Folder(name: newFolderName)
        modelContext.insert(folder)
        newFolderName = ""
        showCreateFolder = false
    }
}

#Preview {
    CollectionsView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Folder.self], inMemory: true)
}
