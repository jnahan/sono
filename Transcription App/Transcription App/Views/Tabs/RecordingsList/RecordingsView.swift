import SwiftUI
import SwiftData

struct RecordingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query(sort: \Recording.recordedAt, order: .reverse) private var recordings: [Recording]
    @Query(sort: \Collection.name) private var collections: [Collection]
    
    @StateObject private var viewModel = RecordingListViewModel()
    
    @State private var selectedRecording: Recording?
    @State private var selectedRecordingForProgress: Recording?
    @State private var showSettings = false
    @State private var showMoveToCollection = false
    @State private var showDeleteConfirm = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        // Custom Top Bar
                        CustomTopBar(
                            title: viewModel.isSelectionMode ? "\(viewModel.selectedRecordings.count) selected" : "Recordings",
                            leftIcon: viewModel.isSelectionMode ? "x" : "check-circle",
                            rightIcon: viewModel.isSelectionMode ? nil : "gear-six",
                            onLeftTap: {
                                if viewModel.isSelectionMode {
                                    viewModel.exitSelectionMode()
                                } else {
                                    viewModel.enterSelectionMode()
                                }
                            },
                            onRightTap: { showSettings = true }
                        )
                        
                        if viewModel.showCopyToast {
                            CopyToastView()
                                .zIndex(1)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 10)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            if !recordings.isEmpty {
                                SearchBar(text: $viewModel.searchText, placeholder: "Search recordings...")
                                    .padding(.horizontal, AppConstants.UI.Spacing.large)
                            }
                            
                            recordingsList
                        }
                        .padding(.top, 8)
                    }
                    
                    // Mass action buttons (fixed at bottom above tab bar, only in selection mode)
                    if viewModel.isSelectionMode && !viewModel.selectedRecordings.isEmpty {
                        MassActionButtons(
                            onDelete: { showDeleteConfirm = true },
                            onCopy: { copySelectedRecordings() },
                            onMove: { showMoveToCollection = true },
                            horizontalPadding: AppConstants.UI.Spacing.large,
                            bottomPadding: 12,
                            bottomSafeAreaPadding: 8
                        )
                    }
                }
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
                viewModel.recoverIncompleteRecordings(recordings)
                // Reset navigation state when returning to this tab
                selectedRecording = nil
                // Show tab bar on root view
                showPlusButton.wrappedValue = true
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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
            .sheet(item: $selectedRecordingForProgress) { recording in
                TranscriptionProgressSheet(recording: recording, onComplete: { completedRecording in
                    // When transcription completes, dismiss sheet and navigate to RecordingDetailsView
                    selectedRecordingForProgress = nil
                    selectedRecording = completedRecording
                })
            }
            .navigationDestination(item: $selectedRecording) { recording in
                RecordingDetailsView(recording: recording, onDismiss: {
                    // Explicitly clear selection to pop back to RecordingsView
                    selectedRecording = nil
                    if navigationPath.count > 0 {
                        navigationPath.removeLast(navigationPath.count)
                    }
                })
                    .onAppear { showPlusButton.wrappedValue = false }
                    .onDisappear {
                        if selectedRecording?.id == recording.id {
                            selectedRecording = nil
                        }
                    }
            }
            .onChange(of: selectedRecording) { oldValue, newValue in
                // When navigating to a recording, add to path
                if newValue != nil {
                    navigationPath.append("recording-\(newValue!.id)")
                } else if oldValue != nil {
                    // When clearing, ensure path is cleared
                    navigationPath.removeLast(navigationPath.count)
                    showPlusButton.wrappedValue = true
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
                .onAppear { showPlusButton.wrappedValue = false }
            }
            .background(Color.warmGray50.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
    
    private var recordingsList: some View {
        RecordingsListView(
            recordings: viewModel.filteredRecordings,
            viewModel: viewModel,
            emptyStateView: AnyView(RecordingEmptyStateView()),
            onRecordingTap: { recording in
                // Only allow navigation to details if transcription is completed
                // Otherwise show progress sheet
                if recording.status == .completed {
                    selectedRecording = recording
                } else {
                    // Show progress sheet for in-progress, failed, or notStarted
                    selectedRecordingForProgress = recording
                }
            },
            onDelete: nil,
            horizontalPadding: AppConstants.UI.Spacing.large,
            bottomContentMargin: 120
        )
    }

    // MARK: - Selection Mode Actions
    
    private func deleteSelectedRecordings() {
        // Cancel any active transcriptions before deleting (handled in viewModel.deleteRecordings)
        viewModel.deleteRecordings(viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings))
    }
    
    private func copySelectedRecordings() {
        viewModel.copyRecordings(viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings))
    }
}
