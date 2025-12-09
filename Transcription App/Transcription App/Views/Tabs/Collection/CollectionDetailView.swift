import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recording.recordedAt, order: .reverse) private var allRecordings: [Recording]
    @Query(sort: \Collection.name) private var collections: [Collection]
    
    @StateObject private var viewModel = RecordingListViewModel()
    
    let collection: Collection
    var showPlusButton: Binding<Bool>
    
    @State private var selectedRecording: Recording?
    @State private var showMenu = false
    @State private var editingCollection = false
    @State private var editCollectionName = ""
    @State private var deletingCollection = false
    @State private var showMoveToCollection = false
    @State private var showDeleteConfirm = false
    
    private var recordings: [Recording] {
        allRecordings.filter { $0.collection?.id == collection.id }
            .sorted { $0.recordedAt > $1.recordedAt }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                CustomTopBar(
                    title: viewModel.isSelectionMode ? "\(viewModel.selectedRecordings.count) selected" : collection.name,
                    leftIcon: viewModel.isSelectionMode ? "x" : "caret-left",
                    rightIcon: viewModel.isSelectionMode ? nil : (viewModel.filteredRecordings.isEmpty ? "dots-three-bold" : "check-circle"),
                    onLeftTap: {
                        if viewModel.isSelectionMode {
                            viewModel.exitSelectionMode()
                        } else {
                            dismiss()
                        }
                    },
                    onRightTap: {
                        if viewModel.isSelectionMode {
                            // Shouldn't happen, but handle it
                        } else if !viewModel.filteredRecordings.isEmpty {
                            viewModel.enterSelectionMode()
                        } else {
                            showMenu = true
                        }
                    }
                )
                
                if viewModel.showCopyToast {
                    CopyToastView()
                        .zIndex(1)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    if !recordings.isEmpty {
                        SearchBar(text: $viewModel.searchText, placeholder: "Search recordings...")
                            .padding(.horizontal, 20)
                    }
                    
                    recordingsList
                }
            }
            
            // Mass action buttons (fixed at bottom, 8px above safe area, only in selection mode)
            if viewModel.isSelectionMode && !viewModel.selectedRecordings.isEmpty {
                MassActionButtons(
                    onDelete: { showDeleteConfirm = true },
                    onCopy: { copySelectedRecordings() },
                    onMove: { showMoveToCollection = true },
                    horizontalPadding: 20,
                    bottomPadding: 8,
                    bottomSafeAreaPadding: 8
                )
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
                    // Cancel any active transcriptions before deleting
                    for recording in recordings {
                        TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)
                    }
                    
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
            RecordingDetailsView(recording: recording, onDismiss: {
                // Explicitly clear selection to navigate back to CollectionDetailView
                selectedRecording = nil
            })
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
                    onExit: nil
                )
        }
        .sheet(isPresented: $showMoveToCollection) {
            CollectionPickerSheet(
                collections: collections,
                selectedCollection: .constant(nil),
                modelContext: modelContext,
                isPresented: $showMoveToCollection,
                recordings: viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings),
                onMassMoveComplete: {
                    viewModel.exitSelectionMode()
                },
                showRemoveFromCollection: true
            )
        }
        .sheet(isPresented: $showDeleteConfirm) {
            ConfirmationSheet(
                isPresented: $showDeleteConfirm,
                title: "Delete \(viewModel.selectedRecordings.count) recording\(viewModel.selectedRecordings.count == 1 ? "" : "s")?",
                message: "Are you sure you want to delete \(viewModel.selectedRecordings.count) recording\(viewModel.selectedRecordings.count == 1 ? "" : "s")? This action cannot be undone.",
                confirmButtonText: "Delete",
                cancelButtonText: "Cancel",
                onConfirm: {
                    deleteSelectedRecordings()
                    showDeleteConfirm = false
                    viewModel.exitSelectionMode()
                }
            )
        }
        .onChange(of: viewModel.searchText) { oldValue, newValue in
            viewModel.updateFilteredRecordings(from: recordings)
        }
        .onChange(of: recordings) { oldValue, newValue in
            viewModel.updateFilteredRecordings(from: recordings)
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext)
            viewModel.updateFilteredRecordings(from: recordings)
            showPlusButton.wrappedValue = false
            // Reset navigation state when returning to this view
            selectedRecording = nil
        }
    }
    
    // MARK: - Selection Mode Actions
    
    private func deleteSelectedRecordings() {
        let selectedArray = viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings)
        // Cancel any active transcriptions before deleting
        for recording in selectedArray {
            TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)
        }
        viewModel.deleteRecordings(selectedArray)
    }
    
    private func copySelectedRecordings() {
        viewModel.copyRecordings(viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings))
    }
    
    private var recordingsList: some View {
        Group {
            if recordings.isEmpty {
                VStack(spacing: 16) {
                    Text(collection.name + " is empty")
                        .font(.libreMedium(size: 24))
                        .foregroundColor(.baseBlack)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 280)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                Spacer()
            } else {
                List {
                    ForEach(viewModel.filteredRecordings) { recording in
                        Button {
                            if viewModel.isSelectionMode {
                                // Toggle selection
                                viewModel.toggleSelection(for: recording.id)
                            } else {
                                selectedRecording = recording
                            }
                        } label: {
                            RecordingRowView(
                                recording: recording,
                                onCopy: { viewModel.copyRecording(recording) },
                                onEdit: { viewModel.editRecording(recording) },
                                onDelete: { viewModel.deleteRecording(recording) },
                                isSelectionMode: viewModel.isSelectionMode,
                                isSelected: viewModel.isSelected(recording.id),
                                onSelectionToggle: {
                                    viewModel.toggleSelection(for: recording.id)
                                }
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
                let recording = viewModel.filteredRecordings[index]
                // Cancel any active transcription before deleting
                TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)
                modelContext.delete(recording)
            }
        }
    }
}
