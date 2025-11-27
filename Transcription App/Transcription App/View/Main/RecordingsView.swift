import SwiftUI
import SwiftData

struct RecordingsView: View {
    // MARK: - Environment & Queries
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query private var recordings: [Recording]
    
    // MARK: - State Objects
    @StateObject private var player = MiniPlayer()
    
    // MARK: - State
    @State private var searchText = ""
    @State private var filteredRecordings: [Recording] = []
    @State private var selectedRecording: Recording?
    @State private var showSettings = false
    
    // MARK: - Edit State
    @State private var editingRecording: Recording?
    @State private var newRecordingTitle = ""
    
    // MARK: - Toast
    @State private var showCopyToast = false
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Copy Toast
                    if showCopyToast {
                        toastView
                    }
                    
                    // Main Content
                    VStack(alignment: .leading, spacing: 20) {
                        headerView
                        recordingsList
                    }
                }
                
                // Edit Overlay
                if editingRecording != nil {
                    editOverlay
                }
            }
            .searchable(text: $searchText, prompt: "Search recordings")
            .onChange(of: searchText) { _ in updateFilteredRecordings() }
            .onChange(of: recordings) { _ in updateFilteredRecordings() }
            .onAppear {
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
    
    // MARK: - Subviews
    private var toastView: some View {
        Text("Recording copied")
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .shadow(radius: 5)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .zIndex(1)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
    }
    
    private var headerView: some View {
        HStack {
            Text("My Recordings")
                .font(.largeTitle)
                .bold()
            
            Spacer()
            
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var recordingsList: some View {
        List {
            ForEach(filteredRecordings) { recording in
                Button {
                    selectedRecording = recording
                } label: {
                    RecordingRow(
                        recording: recording,
                        player: player,
                        onCopy: { copyRecording(recording) },
                        onEdit: { editRecording(recording) },
                        onDelete: { deleteRecording(recording) }
                    )
                }
            }
            .onDelete(perform: deleteRecordings)
        }
        .listStyle(.plain)
    }
    
    private var editOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    editingRecording = nil
                }
            
            VStack(spacing: 20) {
                Text("Edit Recording Title")
                    .font(.headline)
                
                TextField("New Title", text: $newRecordingTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                HStack {
                    Button("Cancel") {
                        editingRecording = nil
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save") {
                        saveEdit()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .frame(maxWidth: 400)
            .shadow(radius: 20)
        }
    }
    
    // MARK: - Helper Methods
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
    
    private func copyRecording(_ recording: Recording) {
        UIPasteboard.general.string = recording.fullText
        withAnimation { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopyToast = false }
        }
    }
    
    private func editRecording(_ recording: Recording) {
        editingRecording = recording
        newRecordingTitle = recording.title
    }
    
    private func deleteRecording(_ recording: Recording) {
        modelContext.delete(recording)
    }
    
    private func deleteRecordings(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(recordings[index])
            }
        }
    }
    
    private func saveEdit() {
        guard let editing = editingRecording else { return }
        editing.title = newRecordingTitle
        editingRecording = nil
    }
}

// MARK: - URL Extension
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

// MARK: - Preview
#Preview {
    RecordingsView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Folder.self], inMemory: true)
}
