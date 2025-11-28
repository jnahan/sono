import SwiftUI
import SwiftData

struct RecordingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query private var recordings: [Recording]
    
    @StateObject private var viewModel = RecordingListViewModel()
    
    @State private var searchText = ""
    @State private var filteredRecordings: [Recording] = []
    @State private var selectedRecording: Recording?
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    if viewModel.showCopyToast {
                        CopyToast()
                            .zIndex(1)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        headerView
                        
                        SearchBar(text: $searchText, placeholder: "Search recordings")
                            .padding(.horizontal, 16)
                        
                        recordingsList
                        Image("gear-six")
                            .resizable()
                            .foregroundColor(.accent)
                            .frame(width: 64, height: 64)

                    }
                }
                
                if viewModel.editingRecording != nil {
                    EditRecordingOverlay(
                        isPresented: Binding(
                            get: { viewModel.editingRecording != nil },
                            set: { if !$0 { viewModel.cancelEdit() } }
                        ),
                        newTitle: $viewModel.newRecordingTitle,
                        onSave: viewModel.saveEdit
                    )
                }
            }
            .onChange(of: searchText) { _ in updateFilteredRecordings() }
            .onChange(of: recordings) { _ in updateFilteredRecordings() }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                updateFilteredRecordings()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(item: $selectedRecording) { recording in
                RecordingDetailsView(recording: recording)
                    .onAppear { showPlusButton.wrappedValue = false }
                    .onDisappear { showPlusButton.wrappedValue = true }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("My Recordings")
                .bold()
                .font(.custom("LibreBaskerville-Regular", size: 20))
        

            Spacer()
            
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.title3)
                    .foregroundColor(.baseBlack)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var recordingsList: some View {
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
            }
            .onDelete(perform: deleteRecordings)
        }
        .listStyle(.plain)
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

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

#Preview {
    RecordingsView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Folder.self], inMemory: true)
}
