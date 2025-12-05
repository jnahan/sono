import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allRecordings: [Recording]
    @Query private var collections: [Collection]
    
    @StateObject private var viewModel = RecordingListViewModel()
    
    let collection: Collection
    var showPlusButton: Binding<Bool>
    
    @State private var searchText = ""
    @State private var selectedRecording: Recording?
    @State private var showMenu = false
    @State private var editingCollection = false
    @State private var editCollectionName = ""
    @State private var deletingCollection = false
    
    private var recordings: [Recording] {
        allRecordings.filter { $0.collection?.id == collection.id }
            .sorted { $0.recordedAt > $1.recordedAt }
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
                title: collection.name,
                leftIcon: "caret-left",
                rightIcon: "dots-three",
                onLeftTap: { dismiss() },
                onRightTap: { showMenu = true }
            )
            
            if viewModel.showCopyToast {
                CopyToastView()
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
        .environment(\.showPlusButton, showPlusButton)
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Rename") {
                editingCollection = true
                editCollectionName = collection.name
            }
            
            Button("Delete", role: .destructive) {
                deletingCollection = true
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $editingCollection) {
            CollectionFormSheet(
                isPresented: $editingCollection,
                collectionName: $editCollectionName,
                isEditing: true,
                onSave: {
                    collection.name = editCollectionName
                    editingCollection = false
                },
                existingCollections: collections,
                currentCollection: collection
            )
        }
        .sheet(isPresented: $deletingCollection) {
            ConfirmationSheet(
                isPresented: $deletingCollection,
                title: "Delete collection?",
                message: "Are you sure you want to delete \"\(collection.name)\"? This will remove all \(recordings.count) recording\(recordings.count == 1 ? "" : "s") in this collection.",
                confirmButtonText: "Delete collection",
                cancelButtonText: "Cancel",
                onConfirm: {
                    // Delete all recordings in this collection
                    for recording in recordings {
                        modelContext.delete(recording)
                    }
                    
                    // Delete the collection
                    modelContext.delete(collection)
                    deletingCollection = false
                    dismiss()
                }
            )
        }
        .navigationDestination(item: $selectedRecording) { recording in
            RecordingDetailsView(recording: recording)
        }
        .navigationDestination(item: $viewModel.editingRecording) { recording in
            RecordingFormView(
                isPresented: Binding(
                    get: { viewModel.editingRecording != nil },
                    set: { if !$0 { viewModel.cancelEdit() } }
                ),
                audioURL: nil,
                existingRecording: recording,
                collections: collections,
                modelContext: modelContext,
                onTranscriptionComplete: {},
                onExit: nil
            )
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext)
            showPlusButton.wrappedValue = false
            // Reset navigation state when returning to this view
            selectedRecording = nil
        }
    }
    
    private var recordingsList: some View {
        Group {
            if recordings.isEmpty {
                VStack(spacing: 16) {
                    Text(collection.name + " is empty")
                        .font(.libreMedium(size: 24))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 280)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                Spacer()
            } else {
                List {
                    ForEach(filteredRecordings) { recording in
                        Button {
                            selectedRecording = recording
                        } label: {
                            RecordingRowView(
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
