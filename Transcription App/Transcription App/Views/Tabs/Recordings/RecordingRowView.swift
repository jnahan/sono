import SwiftUI
import SwiftData

/// Reusable row component for displaying a recording with menu actions
struct RecordingRowView: View {
    // MARK: - Properties
    let recording: Recording
    let onCopy: () -> Void
    let onDelete: () -> Void
    let collections: [Collection]
    let modelContext: ModelContext

    // Selection mode properties
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelectionToggle: (() -> Void)? = nil

    @State private var showDeleteConfirm = false
    @State private var showCollectionPicker = false
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
                                .stroke(isSelected ? Color.accent : Color.blueGray300, lineWidth: 2)
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
                                    .foregroundColor(.white)
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
                        .foregroundColor(.blueGray400)
                    
                    // Title
                    Text(recording.title)
                        .font(.dmSansSemiBold(size: 16))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    // Transcript preview, progress indicator, queue status, or error message
                    // CRITICAL: Check for fullText FIRST, regardless of status - catches completion before status propagates
                    if !recording.fullText.isEmpty {
                        if recording.status == .completed {
                            // Transcription completed and status propagated - show preview
                            Text(recording.fullText)
                                .font(.system(size: 14))
                                .foregroundColor(.blueGray700)
                                .lineLimit(3)
                                .lineSpacing(4)
                        } else {
                            // Transcription completed but status not .completed yet - show saving message
                            // This prevents "Preparing to transcribe..." from showing after transcription completes
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                                
                                Text("Saving transcription")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blueGray500)
                            }
                        }
                    } else if recording.status == .inProgress || recording.status == .notStarted {
                        // Check if there's a failure reason (interrupted transcription)
                        if let failureReason = recording.failureReason, !failureReason.isEmpty {
                            // Show interruption message in gray (can resume)
                            Text(failureReason)
                                .font(.system(size: 14))
                                .foregroundColor(.blueGray500)
                                .italic()
                        } else if let progress = progressManager.getProgress(for: recording.id), progress > 0 {
                            // Has progress - show transcribing with percentage
                            // This ensures we show "Transcribing X%" instead of "Preparing" when transcription is active
                            if let positionInfo = progressManager.getOverallPosition(for: recording.id) {
                                // Show with queue position if available
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.8)
                                    
                                    if positionInfo.position == 1 {
                                        Text("Transcribing \(Int(progress * 100))% (\(positionInfo.position)/\(positionInfo.total))")
                                            .font(.system(size: 14))
                                            .foregroundColor(.blueGray500)
                                    } else {
                                        Text("Waiting to transcribe (\(positionInfo.position)/\(positionInfo.total))")
                                            .font(.system(size: 14))
                                            .foregroundColor(.blueGray500)
                                    }
                                }
                            } else {
                                // Show transcribing without position info
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.8)
                                    
                                    Text("Transcribing \(Int(progress * 100))%")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blueGray500)
                                }
                            }
                        } else if let positionInfo = progressManager.getOverallPosition(for: recording.id) {
                            // Has position info but no progress yet
                            if positionInfo.position == 1 {
                                // Position 1 but no progress - actively preparing to start
                                Text("Preparing to transcribe...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blueGray500)
                                    .italic()
                            } else {
                                // Waiting in queue
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.8)
                                    
                                    Text("Waiting to transcribe (\(positionInfo.position)/\(positionInfo.total))")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blueGray500)
                                }
                            }
                        } else {
                            // In progress but not in queue and no progress - will auto-start soon
                            Text("Preparing to transcribe...")
                                .font(.system(size: 14))
                                .foregroundColor(.blueGray500)
                                .italic()
                        }
                    } else if recording.status == .failed {
                        // Show failure reason in red warning color (cannot retry)
                        Text(recording.failureReason ?? "Failed to transcribe audio. Please delete this recording.")
                            .font(.system(size: 14))
                            .foregroundColor(.warning)
                            .italic()
                    } else {
                        Text("No transcription available")
                            .font(.system(size: 14))
                            .foregroundColor(.blueGray500)
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
                            ActionItem(title: "Add to collection", icon: "folder-open", action: {
                                showCollectionPicker = true
                            }),
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

        .sheet(isPresented: $showCollectionPicker) {
            CollectionPickerSheet(
                collections: collections,
                selectedCollections: .constant(Set<Collection>()),
                modelContext: modelContext,
                isPresented: $showCollectionPicker,
                recordings: [recording],
                onMassMoveComplete: nil
            )
        }
    }
    
    // MARK: - Computed Properties
}


