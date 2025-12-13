import SwiftUI
import SwiftData
import AVFoundation

enum RecordingDetailTab {
    case transcript
    case summary
    case askSono
}

struct RecordingDetailsView: View {
    let recording: Recording
    var onDismiss: (() -> Void)? = nil
    @StateObject private var audioPlayback = AudioPlaybackService()
    @StateObject private var viewModel: RecordingDetailsViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.showPlusButton) private var showPlusButton
    @Query(sort: \Collection.name) private var collections: [Collection]

    init(recording: Recording, onDismiss: (() -> Void)? = nil) {
        self.recording = recording
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: RecordingDetailsViewModel(recording: recording))
    }

    @State private var showNotePopup = false
    @State private var showEditRecording = false
    @State private var showDeleteConfirm = false
    @State private var selectedTab: RecordingDetailTab = .transcript

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Custom Top Bar
                CustomTopBar(
                    title: "",
                    leftIcon: "caret-left",
                    rightIcon: "dots-three-bold",
                    onLeftTap: {
                        // Show tab bar when going back
                        showPlusButton.wrappedValue = true
                        // Use callback if provided, otherwise use dismiss
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    },
                    onRightTap: {
                        ActionSheetManager.shared.show(actions: [
                            ActionItem(title: "Copy transcription", icon: "copy", action: {
                                UIPasteboard.general.string = recording.fullText
                            }),
                            ActionItem(title: "Share transcription", icon: "export", action: {
                                ShareHelper.shareText(recording.fullText)
                            }),
                            ActionItem(title: "Export audio", icon: "waveform", action: {
                                if let url = recording.resolvedURL {
                                    ShareHelper.shareFile(at: url)
                                }
                            }),
                            ActionItem(title: "Edit", icon: "pencil-simple", action: {
                                showEditRecording = true
                            }),
                            ActionItem(title: "Delete", icon: "trash", action: {
                                showDeleteConfirm = true
                            }, isDestructive: true)
                        ])
                    }
                )
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(TimeFormatter.dateWithTime(from: recording.recordedAt))
                        .font(.dmSansMedium(size: 14))
                        .foregroundColor(.warmGray400)

                    Text(recording.title)
                        .font(.dmSansMedium(size: 24))
                        .foregroundColor(.baseBlack)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppConstants.UI.Spacing.large)
                .padding(.top, 8)

                // Tab Selector
                HStack(spacing: 16) {
                    TabButton(
                        title: "Transcript",
                        isSelected: selectedTab == .transcript,
                        action: { selectedTab = .transcript }
                    )

                    TabButton(
                        title: "Summary",
                        isSelected: selectedTab == .summary,
                        action: { selectedTab = .summary }
                    )

                    TabButton(
                        title: "Ask Sono",
                        isSelected: selectedTab == .askSono,
                        action: { selectedTab = .askSono }
                    )

                    Spacer()
                }
                .padding(.horizontal, AppConstants.UI.Spacing.large)
                .padding(.top, 16)

                // Content Area
                VStack(spacing: 0) {
                    if selectedTab == .transcript {
                        transcriptView
                    } else if selectedTab == .summary {
                        summaryView
                    } else {
                        askSonoView
                    }
                }
                .padding(.top, 24)

                Spacer()
            }
            
            // Audio Player Controls (Fixed at bottom) - Only show in transcript tab
            if selectedTab == .transcript {
                VStack {
                    Spacer()

                    RecordingPlayerBar(
                        audioService: audioPlayback,
                        audioURL: recording.resolvedURL,
                        fullText: recording.fullText,
                        onNotePressed: {
                            showNotePopup = true
                        },
                        onSharePressed: {
                            if let url = recording.resolvedURL {
                                ShareHelper.shareItems([recording.fullText, url])
                            } else {
                                ShareHelper.shareText(recording.fullText)
                            }
                        },
                        onAIPressed: {
                            selectedTab = .askSono
                        }
                    )
                }
            }
            
            // Note Overlay
            if showNotePopup {
                NoteOverlay(
                    isPresented: $showNotePopup,
                    noteText: recording.notes
                )
                .zIndex(100)
            }
        }
        .background(Color.warmGray50.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showEditRecording) {
            RecordingFormView(
                isPresented: $showEditRecording,
                audioURL: nil,
                existingRecording: recording,
                collections: collections,
                modelContext: modelContext,
                onExit: nil
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
                    // Cancel any active transcription before deleting
                    TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)
                    modelContext.delete(recording)
                    showDeleteConfirm = false
                    dismiss()
                }
            )
        }
        .onAppear {
            // Hide preview bar and handle audio switching
            let audioManager = AudioPlayerManager.shared

            // If global player is playing a different recording, stop it
            if let currentGlobal = audioManager.currentRecording, currentGlobal.id != recording.id {
                audioManager.stop()
            }

            // If global player is playing the same recording, sync state to local player
            if let currentGlobal = audioManager.currentRecording, currentGlobal.id == recording.id {
                let wasPlaying = audioManager.player.isPlaying
                let currentTime = audioManager.player.currentTime
                audioManager.stop() // Stop global player

                // Load and sync to local player
                if let url = recording.resolvedURL {
                    audioPlayback.preload(url: url)
                    audioPlayback.seek(to: currentTime)
                    if wasPlaying {
                        audioPlayback.play()
                    }
                }
            } else {
                // Just load the audio
                if let url = recording.resolvedURL {
                    audioPlayback.preload(url: url)
                }
            }

            // Set active recording details ID to hide preview bar
            audioManager.activeRecordingDetailsId = recording.id

        }
        .onDisappear {
            audioPlayback.stop()
            // Clear active recording details ID to show preview bar again
            AudioPlayerManager.shared.clearActiveRecordingDetails()
            // Ensure tab bar is shown when leaving details view
            showPlusButton.wrappedValue = true
        }
    }
    
    // MARK: - Transcript View

    private var transcriptView: some View {
        TranscriptView(
            recording: recording,
            audioPlayback: audioPlayback,
            viewModel: viewModel
        ) 
        .id(recording.id)
    }
    
    // MARK: - Summary View

    // Remove the old summaryView computed property and replace with:
    private var summaryView: some View {
        SummaryView(recording: recording)
            .id(recording.id)  // Force view recreation when recording changes
    }
    
    // MARK: - Ask Sono View

    private var askSonoView: some View {
        AskSonoView(recording: recording)
            .id(recording.id)  // Force view recreation when recording changes
    }
}

