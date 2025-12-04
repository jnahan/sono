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
                    EmptyStateGradient()
                }
                
                VStack(spacing: 0) {
                    // Custom Top Bar
                    CustomTopBar(
                        title: "Recordings",
                        rightIcon: "gear-six",
                        onRightTap: { showSettings = true }
                    )
                    
                    if viewModel.showCopyToast {
                        CopyToast()
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
                RecordingEmptyState()
            } else {
                List {
                    ForEach(filteredRecordings) { recording in
                        Button {
                            selectedRecording = recording
                        } label: {
                            RecordingRow(
                                recording: recording,
                                player: viewModel.player,
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
                    .onDelete(perform: deleteRecordings)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.warmGray50)
            }
        }
    }
    
    private func updateFilteredRecordings() {
        if searchText.isEmpty {
            filteredRecordings = recordings
        } else {
            filteredRecordings = recordings.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.fullText.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func deleteRecordings(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(recordings[index])
            }
        }
    }
}

#Preview {
    RecordingsView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Collection.self], inMemory: true)
}
