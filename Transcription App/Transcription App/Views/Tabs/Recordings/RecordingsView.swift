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
                        
                        VStack(alignment: .leading, spacing: 12) {
                            if !recordings.isEmpty {
                                SearchBar(text: $viewModel.searchText, placeholder: "Search recordings...")
                                    .padding(.horizontal, 20)
                            }
                            
                            recordingsList
                        }
                        .padding(.top, 8)
                    }
                    
                    // Mass action buttons (fixed at bottom above tab bar, only in selection mode)
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
                }
                .overlay(alignment: .top) {
                    if viewModel.showCopyToast {
                        ToastView(message: "Copied transcription")
                            .padding(.top, 8)
                    }
                }
                .onChange(of: viewModel.searchText) { oldValue, newValue in
                viewModel.updateFilteredRecordings(from: recordings)
            }
            .onChange(of: recordings) { oldValue, newValue in
                viewModel.updateFilteredRecordings(from: recordings)
            }
            .onChange(of: viewModel.isSelectionMode) { oldValue, newValue in
                // Hide tab bar in selection mode, show it otherwise
                showPlusButton.wrappedValue = !newValue
            }
            .onReceive(NotificationCenter.default.publisher(for: AppConstants.Notification.recordingSaved)) { notification in
                // Handle notification when a recording is saved
                guard let recordingId = notification.userInfo?["recordingId"] as? UUID else { return }
                
                // Find the recording in the list
                if let recording = recordings.first(where: { $0.id == recordingId }),
                   recording.status != .completed,
                   selectedRecordingForProgress == nil {
                    // Show progress sheet for this recording
                    selectedRecordingForProgress = recording
                }
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                viewModel.updateFilteredRecordings(from: recordings)
                viewModel.recoverIncompleteRecordings(recordings)
                // Reset navigation state when returning to this tab
                selectedRecording = nil
                // Show tab bar on root view (unless in selection mode)
                showPlusButton.wrappedValue = !viewModel.isSelectionMode
            }
            .navigationDestination(item: Binding(
                get: { showSettings ? "settings" : nil },
                set: { 
                    if $0 == nil { 
                        showSettings = false
                        // Show tab bar when returning from settings
                        showPlusButton.wrappedValue = !viewModel.isSelectionMode
                    } else {
                        // Hide tab bar when showing settings
                        showPlusButton.wrappedValue = false
                    }
                }
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
            .sheet(item: $selectedRecordingForProgress) { recording in
                TranscriptionProgressSheet(recording: recording, onComplete: { completedRecording in
                    // When transcription completes, dismiss sheet and navigate to RecordingDetailsView
                    selectedRecordingForProgress = nil
                    selectedRecording = completedRecording
                })
            }
            .navigationDestination(item: $selectedRecording) { recording in
                RecordingDetailsView(recording: recording)
                    .onAppear { showPlusButton.wrappedValue = false }
                    .onDisappear {
                        // Clean up when view disappears (works for both swipe and button tap)
                        if selectedRecording?.id == recording.id {
                            selectedRecording = nil
                        }
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
            .toolbar(.hidden, for: .navigationBar)
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
            horizontalPadding: 20,
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
    
    private func exportSelectedRecordings() {
        viewModel.exportRecordings(viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings))
    }
}
