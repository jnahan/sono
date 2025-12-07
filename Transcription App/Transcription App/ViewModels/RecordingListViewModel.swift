import SwiftUI
import SwiftData

/// Shared logic for displaying and managing a list of recordings
class RecordingListViewModel: ObservableObject {
    // MARK: - Player
    @Published var player = Player()
    
    // MARK: - Edit State
    @Published var editingRecording: Recording?
    
    // MARK: - Toast State
    @Published var showCopyToast = false
    
    // MARK: - Model Context
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Actions
    func copyRecording(_ recording: Recording) {
        UIPasteboard.general.string = recording.fullText
        withAnimation { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.showCopyToast = false }
        }
    }
    
    func editRecording(_ recording: Recording) {
        editingRecording = recording
    }
    
    func deleteRecording(_ recording: Recording) {
        modelContext?.delete(recording)
    }
    
    func cancelEdit() {
        editingRecording = nil
    }
    
    func displayCopyToast() {
        withAnimation { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.showCopyToast = false }
        }
    }
}
