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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @Environment(\.showPlusButton) private var showPlusButton
    @Query(sort: \Collection.name) private var collections: [Collection]
    
    init(recording: Recording, onDismiss: (() -> Void)? = nil) {
        self.recording = recording
        self.onDismiss = onDismiss
    }

    @State private var showNotePopup = false
    @State private var showEditRecording = false
    @State private var showDeleteConfirm = false
    @State private var showMenu = false
    @State private var currentActiveSegmentId: UUID?
    @State private var selectedTab: RecordingDetailTab = .transcript
    @State private var showTranscriptionProgressSheet = false
    
    private var showTimestamps: Bool {
        SettingsManager.shared.showTimestamps
    }
    
    var body: some View {
        ZStack {
            Color.warmGray50
                .ignoresSafeArea()
            
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
                    onRightTap: { showMenu = true }
                )
                
                // Header
                VStack(spacing: 8) {
                    Text(TimeFormatter.relativeDate(from: recording.recordedAt))
                        .font(.system(size: 14))
                        .foregroundColor(.warmGray500)

                    Text(recording.title)
                        .font(.custom("LibreBaskerville-Medium", size: 24))
                        .foregroundColor(.baseBlack)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Tab Selector
                HStack(spacing: 0) {
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
                }
                .padding(.horizontal, AppConstants.UI.Spacing.large)
                .padding(.top, 16)
                
                // Content Area
                if selectedTab == .transcript {
                    transcriptView
                } else if selectedTab == .summary {
                    summaryView
                } else {
                    askSonoView
                }
                
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
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showNotePopup)
        .navigationBarHidden(true)
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            RecordingMenuActions.confirmationDialogButtons(
                recording: recording,
                onCopy: {
                    UIPasteboard.general.string = recording.fullText
                },
                onEdit: {
                    showEditRecording = true
                },
                onDelete: {
                    showDeleteConfirm = true
                }
            )
        }
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if showTimestamps && !recording.segments.isEmpty {
                        // Show segments with timestamps when enabled
                        ForEach(recording.segments.sorted(by: { $0.start < $1.start })) { segment in
                            let isActive = audioPlayback.isPlaying &&
                                         audioPlayback.currentTime >= segment.start &&
                                         audioPlayback.currentTime < segment.end
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(TimeFormatter.formatTimestamp(segment.start))
                                    .font(.custom("Inter-Regular", size: 14))
                                    .foregroundColor(.warmGray400)
                                    .monospacedDigit()
                                
                                Text(attributedText(for: segment.text, isActive: isActive))
                                    .font(.custom("Inter-Regular", size: 16))
                                    .foregroundColor(.baseBlack)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .id(segment.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let url = recording.resolvedURL {
                                    // If already playing, just seek. Otherwise load, seek, and play.
                                    if audioPlayback.isPlaying {
                                        audioPlayback.seek(to: segment.start)
                                    } else {
                                        audioPlayback.preload(url: url)
                                        audioPlayback.seek(to: segment.start)
                                        audioPlayback.play()
                                    }
                                }
                                // Scroll to tapped segment
                                currentActiveSegmentId = segment.id
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(segment.id, anchor: .center)
                                }
                            }
                        }
                    } else {
                        // Show full text when timestamps are disabled or no segments
                        Text(recording.fullText)
                            .font(.custom("Inter-Regular", size: 16))
                            .foregroundColor(.baseBlack)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppConstants.UI.Spacing.large)
                .padding(.top, 24)
                .padding(.bottom, 180)
            }
            .onChange(of: audioPlayback.currentTime) { _, _ in
                if audioPlayback.isPlaying && showTimestamps && !recording.segments.isEmpty {
                    // Find the currently active segment
                    let sortedSegments = recording.segments.sorted(by: { $0.start < $1.start })
                    if let activeSegment = sortedSegments.first(where: { segment in
                        audioPlayback.currentTime >= segment.start && 
                        audioPlayback.currentTime < segment.end
                    }) {
                        // Only scroll if this is a new active segment
                        if currentActiveSegmentId != activeSegment.id {
                            currentActiveSegmentId = activeSegment.id
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(activeSegment.id, anchor: .center)
                            }
                        }
                    }
                }
            }
            .onChange(of: audioPlayback.isPlaying) { _, isPlaying in
                // Reset tracking when playback stops
                if !isPlaying {
                    currentActiveSegmentId = nil
                }
            }
        }
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
    

    // MARK: - Helper Methods

    private func attributedText(for text: String, isActive: Bool) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Guard against empty strings to avoid range errors
        guard !text.isEmpty, attributedString.startIndex < attributedString.endIndex else {
            return attributedString
        }
        
        // Set font and color using attribute container
        var container = AttributeContainer()
        container.font = UIFont(name: "Inter-Regular", size: 16) ?? .systemFont(ofSize: 16)
        container.foregroundColor = UIColor(Color.baseBlack)
        
        if isActive {
            container.backgroundColor = UIColor(Color.accentLight)
        }
        
        // Apply attributes to entire string
        let range = attributedString.startIndex..<attributedString.endIndex
        attributedString[range].mergeAttributes(container)
        
        return attributedString
    }
}
