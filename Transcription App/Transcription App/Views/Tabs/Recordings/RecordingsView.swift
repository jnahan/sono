import SwiftUI
import SwiftData

struct RecordingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var tabBarLockedHidden: Bool
    @Binding var showPlusButton: Bool
    @Binding var isRoot: Bool

    @Query(sort: \Recording.recordedAt, order: .reverse) private var recordings: [Recording]
    @Query(sort: \Collection.name) private var collections: [Collection]

    @StateObject private var viewModel = RecordingListViewModel()

    @State private var selectedRecording: Recording?
    @State private var showSettings = false
    @State private var showMoveToCollection = false
    @State private var showDeleteConfirm = false

    // NEW: drawer + filter
    @State private var showCollectionDrawer = false
    @State private var selectedCollectionFilter: Collection? = nil
    
    @State private var editingCollection: Collection?
    @State private var deletingCollection: Collection?
    @State private var editCollectionName = ""


    // MARK: - Derived

    private var recordingsFilteredByCollection: [Recording] {
        guard let c = selectedCollectionFilter else { return recordings }
        return recordings.filter { rec in
            rec.collections.contains(where: { $0.id == c.id })
        }
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    CustomTopBar(
                        title: viewModel.isSelectionMode ? "\(viewModel.selectedRecordings.count) selected" : "Recordings",
                        leftIcon: viewModel.isSelectionMode ? "x" : "check-circle",
                        // ✅ folder icon when not selecting, otherwise nil
                        rightIcon: viewModel.isSelectionMode ? nil : "folder",
                        onLeftTap: {
                            if viewModel.isSelectionMode {
                                viewModel.exitSelectionMode()
                            } else {
                                viewModel.enterSelectionMode()
                            }
                        },
                        onRightTap: {
                            // Open drawer (only when not selection mode)
                            if !viewModel.isSelectionMode {
                                showCollectionDrawer = true
                            }
                        }
                    )

                    VStack(alignment: .leading, spacing: 12) {
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
                        bottomPadding: 12,
                        bottomSafeAreaPadding: 8
                    )
                }
            }

            // NEW: drawer overlay (functional first)
            if showCollectionDrawer {
                CollectionDrawerView(
                    collections: collections,
                    recordings: recordings,
                    selectedCollection: selectedCollectionFilter,

                    onSelectAll: {
                        selectedCollectionFilter = nil
                        applyFiltersToViewModel()
                    },
                    onSelectCollection: { c in
                        selectedCollectionFilter = c
                        applyFiltersToViewModel()
                    },
                    onRename: { c in
                        editingCollection = c
                        editCollectionName = c.name
                    },
                    onDelete: { c in
                        deletingCollection = c
                    },
                    onClose: { showCollectionDrawer = false }
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
                .zIndex(1000)
            }
        }
        .overlay(alignment: .top) {
            if viewModel.showCopyToast {
                ToastView(message: "Copied transcription")
                    .padding(.top, 8)
            }
        }

        // Whenever search changes, re-filter from the collection-filtered source
        .onChange(of: viewModel.searchText) { _, _ in
            applyFiltersToViewModel()
        }

        // Whenever recordings change (new recording / delete), re-filter
        .onChange(of: recordings) { _, _ in
            applyFiltersToViewModel()
        }

        // Whenever collection selection changes, re-filter
        .onChange(of: selectedCollectionFilter) { _, _ in
            applyFiltersToViewModel()
        }

        .onChange(of: viewModel.isSelectionMode) { _, isSelecting in
            showPlusButton = !isSelecting
            // Optional: prevent changing filter while selecting
            // (you can remove this if you want)
            if isSelecting { showCollectionDrawer = false }
        }

        .onAppear {
            viewModel.configure(modelContext: modelContext)
            viewModel.recoverIncompleteRecordings(recordings)

            selectedRecording = nil
            showPlusButton = !viewModel.isSelectionMode
            applyFiltersToViewModel()
            updateRootState()
        }

        .onChange(of: selectedRecording) { _, _ in updateRootState() }
        .onChange(of: showSettings) { _, _ in updateRootState() }
        .onChange(of: viewModel.editingRecording) { _, _ in updateRootState() }

        // Settings (unchanged)
        .navigationDestination(item: Binding(
            get: { showSettings ? "settings" : nil },
            set: { showSettings = ($0 != nil) }
        )) { _ in
            SettingsView()
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
        .sheet(isPresented: Binding(
            get: { editingCollection != nil },
            set: { if !$0 { editingCollection = nil } }
        )) {
            CollectionFormSheet(
                isPresented: Binding(
                    get: { editingCollection != nil },
                    set: { if !$0 { editingCollection = nil } }
                ),
                collectionName: $editCollectionName,
                isEditing: true,
                onSave: {
                    editingCollection?.name = editCollectionName
                    editingCollection = nil
                },
                existingCollections: collections,
                currentCollection: editingCollection
            )
        }

        .sheet(isPresented: Binding(
            get: { deletingCollection != nil },
            set: { if !$0 { deletingCollection = nil } }
        )) {
            if let collection = deletingCollection {
                ConfirmationSheet(
                    isPresented: Binding(
                        get: { deletingCollection != nil },
                        set: { if !$0 { deletingCollection = nil } }
                    ),
                    title: "Delete collection?",
                    message: "Are you sure you want to delete \"\(collection.name)\"?",
                    confirmButtonText: "Delete",
                    cancelButtonText: "Cancel",
                    onConfirm: {
                        modelContext.delete(collection)
                        deletingCollection = nil

                        // If currently filtered by this collection, reset filter
                        if selectedCollectionFilter?.id == collection.id {
                            selectedCollectionFilter = nil
                            applyFiltersToViewModel()
                        }
                    }
                )
            }
        }


        .navigationDestination(item: $selectedRecording) { recording in
            RecordingDetailsView(recording: recording)
                .onAppear { tabBarLockedHidden = true }
                .onDisappear { tabBarLockedHidden = false }
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

        .background(Color.warmGray50.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Helpers

    private func updateRootState() {
        let pushed =
            (selectedRecording != nil)
            || showSettings
            || (viewModel.editingRecording != nil)

        isRoot = !pushed
    }

    private func applyFiltersToViewModel() {
        // Your VM expects the “source list” and handles search text itself.
        // We provide the collection-filtered source list.
        viewModel.updateFilteredRecordings(from: recordingsFilteredByCollection)
    }

    private var recordingsList: some View {
        RecordingsListView(
            recordings: viewModel.filteredRecordings,
            viewModel: viewModel,
            emptyStateView: AnyView(RecordingEmptyStateView()),
            onRecordingTap: { recording in
                selectedRecording = recording
            },
            onDelete: nil,
            horizontalPadding: 20,
            bottomContentMargin: 120
        )
    }

    private func deleteSelectedRecordings() {
        viewModel.deleteRecordings(viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings))
    }

    private func copySelectedRecordings() {
        viewModel.copyRecordings(viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings))
    }

    private func exportSelectedRecordings() {
        viewModel.exportRecordings(viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings))
    }
}
