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
    @StateObject private var audioPlayer = Player()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var collections: [Collection]

    @State private var showNotePopup = false
    @State private var showEditRecording = false
    @State private var showDeleteConfirm = false
    @State private var showMenu = false
    @State private var currentActiveSegmentId: UUID?
    @State private var selectedTab: RecordingDetailTab = .transcript
    @State private var isTranscribing = false
    @State private var transcriptionProgress: Double = 0.0
    @State private var transcriptionError: String?
    @State private var showWarningToast = false
    
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
                            .foregroundColor(.baseBlack)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                // Warning Toast for incomplete transcription
                if showWarningToast {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transcription Incomplete")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.baseBlack)

                            Text(recording.failureReason ?? "This recording was interrupted and needs to be transcribed.")
                                .font(.system(size: 12))
                                .foregroundColor(.warmGray600)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, AppConstants.UI.Spacing.large)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
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
                    audioPlayer.loadAudio(url: url)
                    audioPlayer.seek(toTime: currentTime)
                    if wasPlaying {
                        audioPlayer.play(url)
                    }
                }
            } else {
                // Just load the audio
                if let url = recording.resolvedURL {
                    audioPlayer.loadAudio(url: url)
                }
            }
            
            // Set active recording details ID to hide preview bar
            audioManager.activeRecordingDetailsId = recording.id

            // Show warning toast if recording is incomplete
            if recording.status == .failed || recording.status == .notStarted {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showWarningToast = true
                }
            }
        }
        .onDisappear {
            audioPlayer.stop()
            // Clear active recording details ID to show preview bar again
            AudioPlayerManager.shared.clearActiveRecordingDetails()
        }
    }
    
    // MARK: - Transcript View

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Transcribe button for incomplete recordings
                    if recording.status == .failed || recording.status == .notStarted {
                        VStack(spacing: 16) {
                            Text(recording.fullText.isEmpty ? "No transcription available" : "Partial transcription available")
                                .font(.system(size: 14))
                                .foregroundColor(.warmGray500)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 24)

                            Button {
                                startTranscription()
                            } label: {
                                if isTranscribing {
                                    HStack(spacing: 12) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .baseWhite))
                                        if transcriptionProgress > 0 {
                                            Text("Transcribing \(Int(transcriptionProgress * 100))%")
                                        } else {
                                            Text("Transcribing...")
                                        }
                                    }
                                } else {
                                    Text("Transcribe")
                                }
                            }
                            .buttonStyle(AppButtonStyle())
                            .disabled(isTranscribing)

                            if let error = transcriptionError {
                                Text(error)
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, AppConstants.UI.Spacing.large)
                            }

                            // Show partial text if available
                            if !recording.fullText.isEmpty {
                                Divider()
                                    .padding(.vertical, 16)

                                Text("Partial Transcript:")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.warmGray500)

                                Text(recording.fullText)
                                    .font(.custom("Inter-Regular", size: 16))
                                    .foregroundColor(.warmGray400)
                                    .opacity(0.7)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, AppConstants.UI.Spacing.large)
                    } else if showTimestamps && !recording.segments.isEmpty {
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
                                    .foregroundColor(.baseBlack)
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
            .id(recording.id)  // Force view recreation when recording changes
    }
    
    // MARK: - Ask Sono View

    private var askSonoView: some View {
        AskSonoView(recording: recording)
            .id(recording.id)  // Force view recreation when recording changes
    }
    
    // MARK: - Transcription

    private func startTranscription() {
        guard let url = recording.resolvedURL else {
            transcriptionError = "Audio file not found"
            return
        }

        isTranscribing = true
        transcriptionProgress = 0.0
        transcriptionError = nil
        recording.status = .inProgress
        recording.transcriptionStartedAt = Date()
        recording.failureReason = nil

        Task {
            do {
                let result = try await TranscriptionService.shared.transcribe(audioURL: url) { progress in
                    Task { @MainActor in
                        self.transcriptionProgress = progress
                    }
                }

                await MainActor.run {
                    // Update recording with transcription
                    recording.fullText = result.text
                    recording.language = result.language
                    recording.status = .completed
                    recording.failureReason = nil

                    // Clear existing segments and add new ones
                    recording.segments.removeAll()
                    for segment in result.segments {
                        let recordingSegment = RecordingSegment(
                            start: segment.start,
                            end: segment.end,
                            text: segment.text
                        )
                        modelContext.insert(recordingSegment)
                        recording.segments.append(recordingSegment)
                    }
                }
                
                // Save to database asynchronously to avoid blocking main thread
                await Task { @MainActor in
                    do {
                        try modelContext.save()
                        transcriptionProgress = 1.0
                        isTranscribing = false
                        withAnimation {
                            showWarningToast = false
                        }
                        print("✅ [RecordingDetails] Transcription completed successfully")
                    } catch {
                        isTranscribing = false
                        transcriptionProgress = 0.0
                        transcriptionError = "Failed to save transcription: \(error.localizedDescription)"
                        recording.status = .failed
                        recording.failureReason = transcriptionError
                    }
                }
            } catch {
                await MainActor.run {
                    isTranscribing = false
                    transcriptionProgress = 0.0
                    transcriptionError = "Transcription failed: \(error.localizedDescription)"
                    recording.status = .failed
                    recording.failureReason = transcriptionError
                }
                
                // Save asynchronously to avoid blocking main thread
                await Task { @MainActor in
                    try? modelContext.save()
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func attributedText(for text: String, isActive: Bool) -> AttributedString {
        var attributedString = AttributedString(text)
        
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
