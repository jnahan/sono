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
    
    @State private var searchText = ""
    @State private var selectedRecording: Recording?
    @State private var showMenu = false
    @State private var editingCollection = false
    @State private var editCollectionName = ""
    @State private var deletingCollection = false
    @State private var isSelectionMode = false
    @State private var selectedRecordings: Set<UUID> = []
    @State private var showMoveToCollection = false
    @State private var showDeleteConfirm = false
    
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
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                CustomTopBar(
                    title: isSelectionMode ? "\(selectedRecordings.count) selected" : collection.name,
                    leftIcon: isSelectionMode ? "x" : "caret-left",
                    rightIcon: isSelectionMode ? nil : (filteredRecordings.isEmpty ? "dots-three-bold" : "check-circle"),
                    onLeftTap: {
                        if isSelectionMode {
                            // Exit selection mode
                            isSelectionMode = false
                            selectedRecordings.removeAll()
                        } else {
                            dismiss()
                        }
                    },
                    onRightTap: {
                        if isSelectionMode {
                            // Shouldn't happen, but handle it
                        } else if !filteredRecordings.isEmpty {
                            // Enter selection mode
                            isSelectionMode = true
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
                        SearchBar(text: $searchText, placeholder: "Search recordings...")
                            .padding(.horizontal, 20)
                    }
                    
                    recordingsList
                }
            }
            
            // Mass action buttons (fixed at bottom, 8px above safe area, only in selection mode)
            if isSelectionMode && !selectedRecordings.isEmpty {
                VStack(spacing: 0) {
                    // Gradient fade at top of buttons
                    LinearGradient(
                        colors: [Color.warmGray50.opacity(0), Color.warmGray50],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)
                    
                    Divider()
                        .background(Color.warmGray200)
                    
                    massActionButtons
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(Color.warmGray50)
                }
                .padding(.bottom, 8)
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
                onTranscriptionComplete: {},
                onExit: nil
            )
        }
        .sheet(isPresented: $showMoveToCollection) {
            CollectionPickerSheet(
                collections: collections,
                selectedCollection: .constant(nil),
                modelContext: modelContext,
                isPresented: $showMoveToCollection,
                recordings: selectedRecordingsArray,
                onMassMoveComplete: {
                    isSelectionMode = false
                    selectedRecordings.removeAll()
                },
                showRemoveFromCollection: true
            )
        }
        .sheet(isPresented: $showDeleteConfirm) {
            ConfirmationSheet(
                isPresented: $showDeleteConfirm,
                title: "Delete \(selectedRecordings.count) recording\(selectedRecordings.count == 1 ? "" : "s")?",
                message: "Are you sure you want to delete \(selectedRecordings.count) recording\(selectedRecordings.count == 1 ? "" : "s")? This action cannot be undone.",
                confirmButtonText: "Delete",
                cancelButtonText: "Cancel",
                onConfirm: {
                    deleteSelectedRecordings()
                    showDeleteConfirm = false
                    isSelectionMode = false
                    selectedRecordings.removeAll()
                }
            )
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext)
            showPlusButton.wrappedValue = false
            // Reset navigation state when returning to this view
            selectedRecording = nil
        }
    }
    
    // MARK: - Selection Mode
    
    private var selectedRecordingsArray: [Recording] {
        filteredRecordings.filter { selectedRecordings.contains($0.id) }
    }
    
    private var massActionButtons: some View {
        HStack(spacing: 12) {
            // Delete button
            Button {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                    Text("Delete")
                        .font(.interMedium(size: 16))
                }
                .foregroundColor(.baseWhite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accent)
                .cornerRadius(12)
            }
            
            // Copy button
            Button {
                copySelectedRecordings()
            } label: {
                HStack(spacing: 8) {
                    Image("copy")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                    Text("Copy")
                        .font(.interMedium(size: 16))
                }
                .foregroundColor(.baseBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.warmGray200)
                .cornerRadius(12)
            }
            
            // Move to collection button
            Button {
                showMoveToCollection = true
            } label: {
                HStack(spacing: 8) {
                    Image("folder-plus")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                    Text("Move")
                        .font(.interMedium(size: 16))
                }
                .foregroundColor(.baseBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.warmGray200)
                .cornerRadius(12)
            }
        }
    }
    
    private func deleteSelectedRecordings() {
        viewModel.deleteRecordings(selectedRecordingsArray)
    }
    
    private func copySelectedRecordings() {
        viewModel.copyRecordings(selectedRecordingsArray)
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
                    ForEach(filteredRecordings) { recording in
                        Button {
                            if isSelectionMode {
                                // Toggle selection
                                if selectedRecordings.contains(recording.id) {
                                    selectedRecordings.remove(recording.id)
                                } else {
                                    selectedRecordings.insert(recording.id)
                                }
                            } else {
                                selectedRecording = recording
                            }
                        } label: {
                            RecordingRowView(
                                recording: recording,
                                onCopy: { viewModel.copyRecording(recording) },
                                onEdit: { viewModel.editRecording(recording) },
                                onDelete: { viewModel.deleteRecording(recording) },
                                isSelectionMode: isSelectionMode,
                                isSelected: selectedRecordings.contains(recording.id),
                                onSelectionToggle: {
                                    if selectedRecordings.contains(recording.id) {
                                        selectedRecordings.remove(recording.id)
                                    } else {
                                        selectedRecordings.insert(recording.id)
                                    }
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
                modelContext.delete(filteredRecordings[index])
            }
        }
    }
}
