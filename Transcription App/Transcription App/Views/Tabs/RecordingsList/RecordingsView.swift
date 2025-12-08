import SwiftUI
import SwiftData

struct RecordingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query(sort: \Recording.recordedAt, order: .reverse) private var recordings: [Recording]
    @Query(sort: \Collection.name) private var collections: [Collection]
    
    @StateObject private var viewModel = RecordingListViewModel()
    
    @State private var searchText = ""
    @State private var filteredRecordings: [Recording] = []
    @State private var selectedRecording: Recording?
    @State private var selectedRecordingForProgress: Recording?
    @State private var showSettings = false
    @State private var isSelectionMode = false
    @State private var selectedRecordings: Set<UUID> = []
    @State private var showMoveToCollection = false
    @State private var showDeleteConfirm = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Gradient at absolute top of screen (when empty)
                if filteredRecordings.isEmpty {
                    EmptyStateGradientView()
                }
                
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        // Custom Top Bar
                        CustomTopBar(
                            title: isSelectionMode ? "\(selectedRecordings.count) selected" : "Recordings",
                            leftIcon: isSelectionMode ? "x" : "check-circle",
                            rightIcon: isSelectionMode ? nil : "gear-six",
                            onLeftTap: {
                                if isSelectionMode {
                                    // Exit selection mode
                                    isSelectionMode = false
                                    selectedRecordings.removeAll()
                                } else {
                                    // Enter selection mode
                                    isSelectionMode = true
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
                        
                        VStack(alignment: .leading, spacing: 16) {
                            if !recordings.isEmpty {
                                SearchBar(text: $searchText, placeholder: "Search recordings")
                                    .padding(.horizontal, AppConstants.UI.Spacing.large)
                            }
                            
                            recordingsList
                        }
                    }
                    
                    // Mass action buttons (fixed at bottom above tab bar, only in selection mode)
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
                                .padding(.horizontal, AppConstants.UI.Spacing.large)
                                .padding(.top, 12)
                                .padding(.bottom, 12)
                                .background(Color.warmGray50)
                                .padding(.bottom, 68) // Space for tab bar
                        }
                    }
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                updateFilteredRecordings()
            }
            .onChange(of: recordings) { oldValue, newValue in
                updateFilteredRecordings()
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                updateFilteredRecordings()
                recoverIncompleteRecordings()
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
                    recordings: selectedRecordingsArray,
                    onMassMoveComplete: {
                        isSelectionMode = false
                        selectedRecordings.removeAll()
                    }
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
            .navigationDestination(item: $selectedRecordingForProgress) { recording in
                TranscriptionProgressView(recording: recording, onComplete: { completedRecording in
                    // When transcription completes, replace TranscriptionProgressView with RecordingDetailsView
                    // Clear progress selection and set details selection
                    selectedRecordingForProgress = nil
                    selectedRecording = completedRecording
                })
                    .onAppear { showPlusButton.wrappedValue = false }
                    .onDisappear {
                        // When leaving TranscriptionProgressView, clear selection
                        if selectedRecordingForProgress?.id == recording.id {
                            selectedRecordingForProgress = nil
                        }
                    }
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
            .onChange(of: selectedRecordingForProgress) { oldValue, newValue in
                // When navigating to progress view, add to path
                if newValue != nil {
                    navigationPath.append("progress-\(newValue!.id)")
                } else if oldValue != nil {
                    // When clearing, ensure path is cleared
                    if navigationPath.count > 0 {
                        navigationPath.removeLast()
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
                    onTranscriptionComplete: {},
                    onExit: nil
                )
                .onAppear { showPlusButton.wrappedValue = false }
            }
            .background(Color.warmGray50)
            .navigationBarHidden(true)
        }
    }
    
    private var recordingsList: some View {
        Group {
            if filteredRecordings.isEmpty {
                RecordingEmptyStateView()
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
                                // If transcription is in progress, show progress view
                                // Otherwise show details
                                if recording.status == .inProgress {
                                    selectedRecordingForProgress = recording
                                } else {
                                    selectedRecording = recording
                                }
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
                        .listRowInsets(EdgeInsets(top: 0, leading: AppConstants.UI.Spacing.large, bottom: 0, trailing: AppConstants.UI.Spacing.large))
                        .listRowSpacing(24)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.warmGray50)
                .contentMargins(.bottom, 120, for: .scrollContent)
            }
        }
    }

    private func updateFilteredRecordings() {
        let sortedRecordings = recordings.sorted { $0.recordedAt > $1.recordedAt }

        if searchText.isEmpty {
            filteredRecordings = sortedRecordings
        } else {
            filteredRecordings = sortedRecordings.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.fullText.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    /// Detect and recover incomplete recordings on app launch
    private func recoverIncompleteRecordings() {
        let incompleteRecordings = recordings.filter { recording in
            recording.status == .inProgress
        }

        guard !incompleteRecordings.isEmpty else { return }

        print("🔄 [Recovery] Found \(incompleteRecordings.count) incomplete recording(s)")

        // Perform save operation asynchronously to avoid blocking main thread
        Task { @MainActor in
            for recording in incompleteRecordings {
                // Mark as failed with explanation
                recording.status = .failed
                recording.failureReason = "Recording was interrupted. The app may have been closed or an error occurred during transcription."
                print("⚠️ [Recovery] Marked recording '\(recording.title)' as failed")
            }

            do {
                try modelContext.save()
                print("✅ [Recovery] Successfully updated incomplete recordings")
            } catch {
                print("❌ [Recovery] Failed to save recovered recordings: \(error)")
            }
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
}
