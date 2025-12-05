import SwiftUI

/// Reusable row component for displaying a recording with menu actions
struct RecordingRow: View {
    // MARK: - Properties
    let recording: Recording
    @ObservedObject var player: Player
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showMenu = false
    @State private var showDeleteConfirm = false
    @State private var duration: TimeInterval = 0
    
    // MARK: - Body
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Recording Info
            VStack(alignment: .leading, spacing: 4) {
                // Duration and date
                Text("\(formattedDuration)  ·  \(relativeDate)")
                    .font(.interMedium(size: 14))
                    .foregroundColor(.warmGray400)
                
                // Title
                Text(recording.title)
                    .font(.interMedium(size: 16))
                    .foregroundColor(.baseBlack)
                    .lineLimit(1)
                
                // Transcript preview
                Text(recording.fullText)
                    .font(.system(size: 14))
                    .foregroundColor(.warmGray600)
                    .lineLimit(3)
            }
            
            Spacer()
            
            // Three-dot menu button
            Button {
                showMenu = true
            } label: {
                Image("dots-three")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.warmGray500)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .onAppear {
            loadDuration()
        }
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Copy transcription") {
                onCopy()
            }
            
            Button("Share transcription") {
                shareTranscription()
            }
            
            Button("Export audio") {
                exportAudio()
            }
            
            Button("Edit") {
                onEdit()
            }
            
            Button("Delete", role: .destructive) {
                showDeleteConfirm = true
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showDeleteConfirm) {
            ConfirmationSheet(
                isPresented: $showDeleteConfirm,
                title: "Delete recording?",
                message: "Are you sure you want to delete \"\(recording.title)\"? This action cannot be undone.",
                confirmButtonText: "Delete recording",
                cancelButtonText: "Cancel",
                onConfirm: {
                    onDelete()
                    showDeleteConfirm = false
                }
            )
        }
    }
    
    // MARK: - Computed Properties
    private var formattedDuration: String {
        TimeFormatter.formatDuration(duration)
    }
    
    private var relativeDate: String {
        TimeFormatter.relativeDate(from: recording.recordedAt)
    }
    
    // MARK: - Actions
    private func loadDuration() {
        guard let url = recording.resolvedURL else { return }
        
        Task {
            do {
                let duration = try await AudioHelper.loadDuration(from: url)
                await MainActor.run {
                    self.duration = duration
                }
            } catch {
                print("Error loading duration: \(error)")
            }
        }
    }
    
    private func shareTranscription() {
        ShareHelper.shareText(recording.fullText)
    }
    
    private func exportAudio() {
        guard let url = recording.resolvedURL else { return }
        ShareHelper.shareFile(at: url)
    }
}
