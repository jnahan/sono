import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allRecordings: [Recording]
    @Query private var folders: [Folder]
    
    @StateObject private var viewModel = RecordingListViewModel()
    
    let folder: Folder
    var showPlusButton: Binding<Bool>
    
    @State private var searchText = ""
    @State private var selectedRecording: Recording?
    @State private var showMenu = false
    @State private var editingFolder = false
    @State private var editFolderName = ""
    @State private var deletingFolder = false
    
    private var recordings: [Recording] {
        allRecordings.filter { $0.folder?.id == folder.id }
    }
    
    private var filteredRecordings: [Recording] {
        if searchText.isEmpty {
            return recordings
        } else {
            return recordings.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.fullText.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            CustomTopBar(
                title: folder.name,
                leftIcon: "caret-left",
                rightIcon: "dots-three",
                onLeftTap: { dismiss() },
                onRightTap: { showMenu = true }
            )
            
            if viewModel.showCopyToast {
                CopyToast()
                    .zIndex(1)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                if !recordings.isEmpty {
                    SearchBar(text: $searchText, placeholder: "Search recordings...")
                        .padding(.horizontal, 20)
                }
                
                recordingsList
            }
        }
        .background(Color.warmGray50.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Rename") {
                editingFolder = true
                editFolderName = folder.name
            }
            
            Button("Delete", role: .destructive) {
                deletingFolder = true
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $editingFolder) {
            CollectionFormSheet(
                isPresented: $editingFolder,
                folderName: $editFolderName,
                isEditing: true,
                onSave: {
                    folder.name = editFolderName
                    editingFolder = false
                }
            )
        }
        .sheet(isPresented: $deletingFolder) {
            DeleteFolderConfirmation(
                isPresented: $deletingFolder,
                folderName: folder.name,
                recordingCount: recordings.count,
                onConfirm: {
                    // Delete all recordings in this folder
                    for recording in recordings {
                        modelContext.delete(recording)
                    }
                    
                    // Delete the folder
                    modelContext.delete(folder)
                    deletingFolder = false
                    dismiss()
                }
            )
        }
        .navigationDestination(item: $selectedRecording) { recording in
            RecordingDetailsView(recording: recording)
                .onAppear { showPlusButton.wrappedValue = false }
                .onDisappear { showPlusButton.wrappedValue = true }
        }
        .navigationDestination(item: $viewModel.editingRecording) { recording in
            RecordingFormView(
                isPresented: Binding(
                    get: { viewModel.editingRecording != nil },
                    set: { if !$0 { viewModel.cancelEdit() } }
                ),
                audioURL: nil,
                existingRecording: recording,
                folders: folders,
                modelContext: modelContext,
                onTranscriptionComplete: {}
            )
            .onAppear { showPlusButton.wrappedValue = false }
            .onDisappear { showPlusButton.wrappedValue = true }
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext)
        }
    }
    
    private var recordingsList: some View {
        Group {
            if recordings.isEmpty {
                VStack(spacing: 16) {
                    Text(folder.name + " is empty")
                        .font(.libreMedium(size: 24))
                }
               .frame(maxWidth: 280)
               .frame(maxHeight: .infinity)
               Spacer()
            } else {
                List {
                    ForEach(filteredRecordings) { recording in
                        Button {
                            selectedRecording = recording
                        } label: {
                            RecordingRow(
                                recording: recording,
                                player: viewModel.player,
                                onCopy: { viewModel.copyRecording(recording) },
                                onEdit: { viewModel.editRecording(recording) },
                                onDelete: { viewModel.deleteRecording(recording) }
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.warmGray50)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowSpacing(24)
                        .listRowSeparator(.hidden)
                    }
                    .onDelete(perform: deleteRecordings)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.warmGray50)
            }
        }
    }
    
    private func deleteRecordings(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredRecordings[index])
            }
        }
    }
}
