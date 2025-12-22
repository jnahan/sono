import SwiftUI
import SwiftData

struct RecordingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var showPlusButton: Bool
    @Binding var navDepth: Int

    @Query(sort: \Recording.recordedAt, order: .reverse) private var recordings: [Recording]
    @Query(sort: \Collection.name) private var collections: [Collection]

    @StateObject private var viewModel = RecordingListViewModel()

    @State private var selectedRecording: Recording?
    @State private var selectedRecordingForProgress: Recording?
    @State private var showSettings = false
    @State private var showMoveToCollection = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
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
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.updateFilteredRecordings(from: recordings)
        }
        .onChange(of: recordings) { _, _ in
            viewModel.updateFilteredRecordings(from: recordings)
        }

        // keep your selection mode logic (this is separate from nav depth)
        .onChange(of: viewModel.isSelectionMode) { _, isSelecting in
            showPlusButton = !isSelecting
        }

        .onReceive(NotificationCenter.default.publisher(for: AppConstants.Notification.recordingSaved)) { notification in
            guard let recordingId = notification.userInfo?["recordingId"] as? UUID else { return }

            if let recording = recordings.first(where: { $0.id == recordingId }),
               recording.status != .completed,
               selectedRecordingForProgress == nil {
                selectedRecordingForProgress = recording
            }
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext)
            viewModel.updateFilteredRecordings(from: recordings)
            viewModel.recoverIncompleteRecordings(recordings)

            selectedRecording = nil
            showPlusButton = !viewModel.isSelectionMode
        }

        // ✅ Settings push (track depth)
        .navigationDestination(item: Binding(
            get: { showSettings ? "settings" : nil },
            set: { showSettings = ($0 != nil) }
        )) { _ in
            SettingsView()
                .trackNavDepth($navDepth)
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
                selectedRecordingForProgress = nil
                selectedRecording = completedRecording
            })
        }

        // ✅ Details push (track depth)
        .navigationDestination(item: $selectedRecording) { recording in
            RecordingDetailsView(recording: recording)
                .trackNavDepth($navDepth)
                .onDisappear {
                    if selectedRecording?.id == recording.id {
                        selectedRecording = nil
                    }
                }
        }

        // ✅ Edit push (track depth)
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
            .trackNavDepth($navDepth)
        }

        .background(Color.warmGray50.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var recordingsList: some View {
        RecordingsListView(
            recordings: viewModel.filteredRecordings,
            viewModel: viewModel,
            emptyStateView: AnyView(RecordingEmptyStateView()),
            onRecordingTap: { recording in
                if recording.status == .completed {
                    selectedRecording = recording
                } else {
                    selectedRecordingForProgress = recording
                }
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
