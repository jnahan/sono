import SwiftUI

/// Reusable row component for displaying a recording with menu actions
struct RecordingRowView: View {
    // MARK: - Properties
    let recording: Recording
    let player: Player // Keep for compatibility but use global manager
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showMenu = false
    @State private var showDeleteConfirm = false
    @State private var duration: TimeInterval = 0
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Recording Info
                VStack(alignment: .leading, spacing: 4) {
                    // Date with time
                    Text(formattedDateWithTime)
                        .font(.interMedium(size: 14))
                        .foregroundColor(.warmGray400)
                    
                    // Title
                    Text(recording.title)
                        .font(.interMedium(size: 16))
                        .foregroundColor(.baseBlack)
                        .lineLimit(1)
                    
                    // Transcript preview
                    if !recording.fullText.isEmpty {
                        Text(recording.fullText)
                            .font(.system(size: 14))
                            .foregroundColor(.warmGray600)
                            .lineLimit(3)
                    } else {
                        Text("No transcription available")
                            .font(.system(size: 14))
                            .foregroundColor(.warmGray400)
                            .italic()
                    }
                }
                
                Spacer()
            }
            
            // Action buttons row
            HStack(spacing: 16) {
                // Play button with duration
                Button {
                    AudioPlayerManager.shared.playRecording(recording)
                } label: {
                    HStack(spacing: 6) {
                        Image(audioManager.player.isPlaying && audioManager.currentRecording?.id == recording.id ? "pause-fill" : "play-fill")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundColor(.baseBlack)
                        
                        Text("Play \(formattedDuration)")
                            .font(.interMedium(size: 14))
                            .foregroundColor(.baseBlack)
                    }
                }
                .buttonStyle(.plain)
                
                // Copy button
                IconButton(icon: "copy") {
                    onCopy()
                }
                
                // Dots three menu button
                IconButton(icon: "dots-three-bold") {
                    showMenu = true
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .onAppear {
            loadDuration()
        }
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            RecordingMenuActions.confirmationDialogButtons(
                recording: recording,
                onCopy: onCopy,
                onEdit: onEdit,
                onDelete: { showDeleteConfirm = true }
            )
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
    
    private var formattedDateWithTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        let dateString = formatter.string(from: recording.recordedAt)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.amSymbol = "AM"
        timeFormatter.pmSymbol = "PM"
        let timeString = timeFormatter.string(from: recording.recordedAt)
        
        return "\(dateString) · \(timeString)"
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
                // Error loading duration - handled silently
            }
        }
    }
    
}


