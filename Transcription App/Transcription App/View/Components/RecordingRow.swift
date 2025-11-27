import SwiftUI

/// Reusable row component for displaying a recording with playback controls and menu actions
struct RecordingRow: View {
    // MARK: - Properties
    let recording: Recording
    @ObservedObject var player: MiniPlayer
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    // MARK: - Body
    var body: some View {
        HStack {
            // Recording Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title)
                    .lineLimit(1)
                
                Text(recording.recordedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Play/Pause Button
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.plain)
            
            // Progress Bar
            ProgressView(value: isPlaying ? player.progress : 0)
                .frame(width: 60)
            
            // Actions Menu
            RecordingActionsMenu(
                recording: recording,
                onCopy: onCopy,
                onEdit: onEdit,
                onDelete: onDelete
            )
        }
    }
    
    // MARK: - Computed Properties
    private var isPlaying: Bool {
        player.playingURL == recording.resolvedURL && player.isPlaying
    }
    
    // MARK: - Actions
    private func togglePlayback() {
        if isPlaying {
            player.pause()
        } else if let url = recording.resolvedURL {
            player.play(url)
        }
    }
}
