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
    
    @State private var showDeleteConfirm = false
    @StateObject private var progressManager = TranscriptionProgressManager.shared
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
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
                    Text(TimeFormatter.dateWithTime(from: recording.recordedAt))
                        .font(.dmSansMedium(size: 12))
                        .foregroundColor(.warmGray400)
                    
                    // Title
                    Text(recording.title)
                        .font(.dmSansSemiBold(size: 16))
                        .foregroundColor(.baseBlack)
                        .lineLimit(1)
                    
                    // Transcript preview, progress indicator, queue status, or error message
                    if recording.status == .inProgress || recording.status == .notStarted {
                        // Check if there's a failure reason (interrupted transcription)
                        if let failureReason = recording.failureReason, !failureReason.isEmpty {
                            // Show interruption message in gray (can resume)
                            Text(failureReason)
                                .font(.system(size: 14))
                                .foregroundColor(.warmGray500)
                                .italic()
                        } else if let positionInfo = progressManager.getOverallPosition(for: recording.id) {
                            // Show queue position with original total
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .baseBlack))
                                    .scaleEffect(0.8)

                                if positionInfo.position == 1 {
                                    // Actively transcribing
                                    if let progress = progressManager.getProgress(for: recording.id), progress > 0 {
                                        Text("Transcribing \(Int(progress * 100))% (\(positionInfo.position)/\(positionInfo.total))")
                                            .font(.system(size: 14))
                                            .foregroundColor(.warmGray500)
                                    } else {
                                        Text("Transcribing (\(positionInfo.position)/\(positionInfo.total))")
                                            .font(.system(size: 14))
                                            .foregroundColor(.warmGray500)
                                    }
                                } else {
                                    // Waiting in queue
                                    Text("Waiting to transcribe (\(positionInfo.position)/\(positionInfo.total))")
                                        .font(.system(size: 14))
                                        .foregroundColor(.warmGray500)
                                }
                            }
                        } else {
                            // In progress but not in queue - will auto-start soon
                            Text("Preparing to transcribe...")
                                .font(.system(size: 14))
                                .foregroundColor(.warmGray500)
                                .italic()
                        }
                    } else if recording.status == .failed {
                        // Show failure reason in red warning color (cannot retry)
                        Text(recording.failureReason ?? "Failed to transcribe audio. Please delete this recording.")
                            .font(.system(size: 14))
                            .foregroundColor(.warning)
                            .italic()
                    } else if !recording.fullText.isEmpty {
                        Text(recording.fullText)
                            .font(.system(size: 14))
                            .foregroundColor(.warmGray700)
                            .lineLimit(3)
                            .lineSpacing(4)
                    } else {
                        Text("No transcription available")
                            .font(.system(size: 14))
                            .foregroundColor(.warmGray500)
                            .italic()
                    }
                }
                
                Spacer()
            }
            
            // Action buttons row (hidden in selection mode)
            if !isSelectionMode {
                HStack(spacing: 8) {
                    // Copy button
                    IconButton(icon: "copy", iconSize: 24, frameSize: 32) {
                        onCopy()
                    }
                    
                    // Dots three menu button
                    ActionButton(
                        icon: "dots-three-bold",
                        iconSize: 24,
                        frameSize: 32,
                        actions: [
                            ActionItem(title: "Copy transcription", icon: "copy", action: onCopy),
                            ActionItem(title: "Share transcription", icon: "export", action: {
                                ShareHelper.shareTranscription(recording.fullText, title: recording.title)
                            }),
                            ActionItem(title: "Export audio", icon: "waveform", action: {
                                if let url = recording.resolvedURL {
                                    ShareHelper.shareFile(at: url)
                                }
                            }),
                            ActionItem(title: "Edit", icon: "pencil-simple", action: onEdit),
                            ActionItem(title: "Delete", icon: "trash", action: { showDeleteConfirm = true }, isDestructive: true)
                        ]
                    )
                    
                    Spacer()
                }
            }
        }
        .padding(.top, 8)
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
}


