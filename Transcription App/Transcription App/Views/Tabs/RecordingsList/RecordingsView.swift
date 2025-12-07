import SwiftUI
import SwiftData

struct RecordingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query private var recordings: [Recording]
    @Query private var collections: [Collection]
    
    @StateObject private var viewModel = RecordingListViewModel()
    
    @State private var searchText = ""
    @State private var filteredRecordings: [Recording] = []
    @State private var selectedRecording: Recording?
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient at absolute top of screen (when empty)
                if filteredRecordings.isEmpty {
                    EmptyStateGradientView()
                }
                
                VStack(spacing: 0) {
                    // Custom Top Bar
                    CustomTopBar(
                        title: "Recordings",
                        rightIcon: "gear-six",
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
            .navigationDestination(item: $selectedRecording) { recording in
                RecordingDetailsView(recording: recording)
                    .onAppear { showPlusButton.wrappedValue = false }
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
                            selectedRecording = recording
                        } label: {
                            RecordingRowView(
                                recording: recording,
                                player: AudioPlayerManager.shared.player,
                                onCopy: { viewModel.copyRecording(recording) },
                                onEdit: { viewModel.editRecording(recording) },
                                onDelete: { viewModel.deleteRecording(recording) }
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

#Preview {
    RecordingsView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Collection.self], inMemory: true)
}
