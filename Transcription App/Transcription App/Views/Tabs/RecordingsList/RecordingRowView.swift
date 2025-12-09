import SwiftUI

/// Reusable row component for displaying a recording with menu actions
struct RecordingRowView: View {
    // MARK: - Properties
    let recording: Recording
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    // Selection mode properties
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelectionToggle: (() -> Void)? = nil
    
    @State private var showMenu = false
    @State private var showDeleteConfirm = false
    @StateObject private var progressManager = TranscriptionProgressManager.shared
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Check circle (only in selection mode)
                if isSelectionMode {
                    Button {
                        onSelectionToggle?()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(isSelected ? Color.accent : Color.warmGray300, lineWidth: 2)
                                .frame(width: 24, height: 24)
                            
                            if isSelected {
                                Circle()
                                    .fill(Color.accent)
                                    .frame(width: 24, height: 24)
                                
                                Image("check-bold")
                                    .resizable()
                                    .renderingMode(.template)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.baseWhite)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                
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
                    
                    // Transcript preview, progress indicator, queue status, or interruption message
                    if progressManager.isQueued(recordingId: recording.id) {
                        // Queued state
                        Text("Waiting to transcribe")
                            .font(.system(size: 14))
                            .foregroundColor(.warmGray500)
                            .italic()
                    } else if recording.status == .inProgress {
                        // Check if there's a failure reason (interrupted transcription)
                        if let failureReason = recording.failureReason, !failureReason.isEmpty {
                            // Show interruption message instead of progress
                            Text(failureReason)
                                .font(.system(size: 14))
                                .foregroundColor(.warmGray500)
                                .italic()
                        } else if progressManager.hasActiveTranscription(for: recording.id) {
                            // Actively transcribing
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .baseBlack))
                                    .scaleEffect(0.8)
                                if let progress = progressManager.getProgress(for: recording.id), progress > 0 {
                                    Text("Transcribing \(Int(progress * 100))%")
                                        .font(.system(size: 14))
                                        .foregroundColor(.warmGray600)
                                } else {
                                    Text("Transcribing...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.warmGray600)
                                }
                            }
                        } else {
                            // In progress but not active - interrupted without message
                            Text("Transcription interrupted. Tap to resume.")
                                .font(.system(size: 14))
                                .foregroundColor(.warmGray500)
                                .italic()
                        }
                    } else if recording.status == .failed || recording.status == .notStarted {
                        Text("Transcription interrupted")
                            .font(.system(size: 14))
                            .foregroundColor(.warmGray500)
                            .italic()
                    } else if !recording.fullText.isEmpty {
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
            
            // Action buttons row (hidden in selection mode)
            if !isSelectionMode {
                HStack(spacing: 16) {
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
        }
        .padding(.vertical, 12)
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
}


