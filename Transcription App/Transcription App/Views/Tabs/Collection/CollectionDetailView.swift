import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recording.recordedAt, order: .reverse) private var allRecordings: [Recording]
    @Query(sort: \Collection.name) private var collections: [Collection]

    @StateObject private var viewModel = RecordingListViewModel()

    let collection: Collection

    @State private var selectedRecording: Recording?
    @State private var editingCollection = false
    @State private var editCollectionName = ""
    @State private var deletingCollection = false
    @State private var showMoveToCollection = false
    @State private var showDeleteConfirm = false

    private var recordings: [Recording] {
        allRecordings
            .filter { rec in rec.collections.contains(where: { $0.id == collection.id }) }
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
                            // no-op
                        } else if !viewModel.filteredRecordings.isEmpty {
                            viewModel.enterSelectionMode()
                        } else {
                            ActionSheetManager.shared.show(actions: [
                                ActionItem(title: "Rename", icon: "pencil-simple", action: {
                                    editingCollection = true
                                    editCollectionName = collection.name
                                }),
                                ActionItem(title: "Delete", icon: "trash", action: {
                                    deletingCollection = true
                                }, isDestructive: true)
                            ])
                        }
                    }
                )

                VStack(alignment: .leading, spacing: 16) {
                    if !recordings.isEmpty {
                        SearchBar(text: $viewModel.searchText, placeholder: "Search recordings...")
                            .padding(.horizontal, 20)
                    }

                    recordingsList
                }
                .padding(.top, 8)
            }

            if viewModel.isSelectionMode {
                MassActionButtons(
                    onDelete: { showDeleteConfirm = true },
                    onCopy: { copySelectedRecordings() },
                    onMove: { showMoveToCollection = true },
                    onExport: { exportSelectedRecordings() },
                    isDisabled: viewModel.selectedRecordings.isEmpty,
                    horizontalPadding: 20,
                    bottomPadding: 8,
                    bottomSafeAreaPadding: 8
                )
            }
        }
        .overlay(alignment: .top) {
            if viewModel.showCopyToast {
                ToastView(message: "Copied transcription")
                    .padding(.top, 8)
            }
        }
        .background(Color.warmGray50.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()

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
                message: "Are you sure you want to delete \"\(collection.name)\"? Recordings in this collection will remain in your library.",
                confirmButtonText: "Delete collection",
                cancelButtonText: "Cancel",
                onConfirm: {
                    modelContext.delete(collection)
                    deletingCollection = false
                    dismiss()
                }
            )
        }

        .navigationDestination(item: $selectedRecording) { recording in
            RecordingDetailsView(recording: recording)
                .onDisappear {
                    if selectedRecording?.id == recording.id {
                        selectedRecording = nil
                    }
                }
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
                selectedCollections: .constant(Set<Collection>()),
                modelContext: modelContext,
                isPresented: $showMoveToCollection,
                recordings: viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings),
                onMassMoveComplete: {
                    viewModel.exitSelectionMode()
                }
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

        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.updateFilteredRecordings(from: recordings)
        }
        .onChange(of: recordings) { _, _ in
            viewModel.updateFilteredRecordings(from: recordings)
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext)
            viewModel.updateFilteredRecordings(from: recordings)
            selectedRecording = nil
        }
    }

    private var recordingsList: some View {
        RecordingsListView(
            recordings: viewModel.filteredRecordings,
            viewModel: viewModel,
            emptyStateView: AnyView(
                VStack(spacing: 16) {
                    Text(collection.name + " is empty")
                        .font(.dmSansSemiBold(size: 24))
                        .foregroundColor(.baseBlack)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 280)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.bottom, 80)
            ),
            onRecordingTap: { recording in
                selectedRecording = recording
            },
            onDelete: deleteRecordings,
            horizontalPadding: 20,
            bottomContentMargin: nil
        )
    }

    private func deleteSelectedRecordings() {
        let selectedArray = viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings)
        for recording in selectedArray {
            TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)
        }
        viewModel.deleteRecordings(selectedArray)
    }

    private func copySelectedRecordings() {
        viewModel.copyRecordings(viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings))
    }

    private func exportSelectedRecordings() {
        viewModel.exportRecordings(viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings))
    }

    private func deleteRecordings(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let recording = viewModel.filteredRecordings[index]
                TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)
                modelContext.delete(recording)
            }
        }
    }
}
