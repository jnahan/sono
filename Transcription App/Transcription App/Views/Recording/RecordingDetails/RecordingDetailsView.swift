import SwiftUI
import SwiftData
import AVFoundation

enum RecordingDetailTab {
    case transcript
    case summary
}

struct RecordingDetailsView: View {
    let recording: Recording
    @StateObject private var audioPlayer = Player()
    @StateObject private var viewModel: RecordingDetailsViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var collections: [Collection]
    
    @State private var showNotePopup = false
    @State private var showEditRecording = false
    @State private var showDeleteConfirm = false
    @State private var showMenu = false
    @State private var currentActiveSegmentId: UUID?
    @State private var selectedTab: RecordingDetailTab = .transcript
    
    init(recording: Recording) {
        self.recording = recording
        _viewModel = StateObject(wrappedValue: RecordingDetailsViewModel(recording: recording))
    }
    
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
                    rightIcon: "dots-three",
                    onLeftTap: { dismiss() },
                    onRightTap: { showMenu = true }
                )
                
                // Header
                VStack(spacing: 12) {
                    Image("asterisk")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)

                    VStack(spacing: 8) {
                        Text(TimeFormatter.relativeDate(from: recording.recordedAt))
                            .font(.system(size: 14))
                            .foregroundColor(.warmGray500)
                        
                        Text(recording.title)
                            .font(.custom("LibreBaskerville-Medium", size: 24))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
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
                }
                .padding(.horizontal, AppConstants.UI.Spacing.large)
                .padding(.top, 16)
                
                // Content Area
                if selectedTab == .transcript {
                    transcriptView
                } else {
                    summaryView
                }
                
                Spacer()
            }
            
            // Audio Player Controls (Fixed at bottom)
            VStack {
                Spacer()
                
                AudioPlayerControls(
                    audioPlayer: audioPlayer,
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
                    }
                )
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
                onTranscriptionComplete: {},
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
            if let url = recording.resolvedURL {
                audioPlayer.loadAudio(url: url)
            }
        }
        .onDisappear {
            audioPlayer.stop()
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
                            let isActive = audioPlayer.isPlaying && 
                                         audioPlayer.currentTime >= segment.start && 
                                         audioPlayer.currentTime < segment.end
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(TimeFormatter.formatTimestamp(segment.start))
                                    .font(.custom("Inter-Regular", size: 14))
                                    .foregroundColor(.warmGray400)
                                    .monospacedDigit()
                                
                                Text(attributedText(for: segment.text, isActive: isActive))
                                    .font(.custom("Inter-Regular", size: 16))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .id(segment.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let url = recording.resolvedURL {
                                    // If already playing, just seek. Otherwise load, seek, and play.
                                    if audioPlayer.isPlaying {
                                        audioPlayer.seek(toTime: segment.start)
                                    } else {
                                        audioPlayer.loadAudio(url: url)
                                        audioPlayer.seek(toTime: segment.start)
                                        audioPlayer.play(url)
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
            .onChange(of: audioPlayer.currentTime) { _, _ in
                if audioPlayer.isPlaying && showTimestamps && !recording.segments.isEmpty {
                    // Find the currently active segment
                    let sortedSegments = recording.segments.sorted(by: { $0.start < $1.start })
                    if let activeSegment = sortedSegments.first(where: { segment in
                        audioPlayer.currentTime >= segment.start && 
                        audioPlayer.currentTime < segment.end
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
            .onChange(of: audioPlayer.isPlaying) { _, isPlaying in
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
    }
    
    // MARK: - Helper Methods
    
    private func attributedText(for text: String, isActive: Bool) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Set font and color using attribute container
        var container = AttributeContainer()
        container.font = UIFont(name: "Inter-Regular", size: 16) ?? .systemFont(ofSize: 16)
        container.foregroundColor = UIColor.black
        
        if isActive {
            container.backgroundColor = UIColor(Color.accentLight)
        }
        
        // Apply attributes to entire string
        let range = attributedString.startIndex..<attributedString.endIndex
        attributedString[range].mergeAttributes(container)
        
        return attributedString
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(isSelected ? .baseBlack : .warmGray400)
                
                Rectangle()
                    .fill(isSelected ? Color.baseBlack : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
