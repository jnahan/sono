import SwiftUI
import SwiftData
import AVFoundation
import UIKit

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
    @StateObject private var progressManager = TranscriptionProgressManager.shared

    @StateObject private var askSonoVM: AskSonoViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Collection.name) private var collections: [Collection]

    init(recording: Recording, onDismiss: (() -> Void)? = nil) {
        self.recording = recording
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: RecordingDetailsViewModel(recording: recording))
        _askSonoVM = StateObject(wrappedValue: AskSonoViewModel(recording: recording))
    }

    @State private var showDeleteConfirm = false
    @State private var showCollectionPicker = false
    @State private var selectedTab: RecordingDetailTab = .transcript
    @State private var currentProgress: Double = 0.0
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showCopyToast = false
    @FocusState private var isTitleFocused: Bool

    // MARK: - Measurements for top title behavior
    @State private var headerHeight: CGFloat = 0
    @State private var topMarkerMinY: CGFloat = 0
    @State private var showTopTitle: Bool = false

    private var scrollOffset: CGFloat { max(0, -topMarkerMinY) }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                CustomTopBar(
                    title: showTopTitle ? recording.title : "",
                    leftIcon: "caret-left",
                    rightIcon: "dots-three-bold",
                    onLeftTap: {
                        if let onDismiss = onDismiss { onDismiss() } else { dismiss() }
                    },
                    onRightTap: {
                        ActionSheetManager.shared.show(actions: [
                            ActionItem(title: "Copy transcription", icon: "copy", action: {
                                UIPasteboard.general.string = recording.fullText
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation { showCopyToast = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { showCopyToast = false }
                                    }
                                }
                            }),
                            ActionItem(title: "Share transcription", icon: "export", action: {
                                ShareHelper.shareTranscription(recording.fullText, title: recording.title)
                            }),
                            ActionItem(title: "Export audio", icon: "waveform", action: {
                                if let url = recording.resolvedURL { ShareHelper.shareFile(at: url) }
                            }),
                            ActionItem(title: "Add to collection", icon: "folder-open", action: {
                                showCollectionPicker = true
                            }),
                            ActionItem(title: "Delete", icon: "trash", action: {
                                showDeleteConfirm = true
                            }, isDestructive: true)
                        ])
                    }
                )

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {

                        // Stable offset marker
                        Color.clear
                            .frame(height: 0)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: TopMarkerMinYPreferenceKey.self,
                                        value: geo.frame(in: .named("recordingDetailsScroll")).minY
                                    )
                                }
                            )

                        // Header (scrolls away)
                        headerView
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: HeaderHeightPreferenceKey.self,
                                        value: geo.size.height
                                    )
                                }
                            )

                        // Sticky tabs
                        Section(header: tabsHeader) {
                            // Each tab can manage its own scrolling internally.
                            Group {
                                switch selectedTab {
                                case .transcript:
                                    TranscriptView(
                                        recording: recording,
                                        audioPlayback: audioPlayback,
                                        viewModel: viewModel
                                    )
                                    .id(recording.id)

                                case .summary:
                                    SummaryView(recording: recording)
                                        .id(recording.id)

                                case .askSono:
                                    AskSonoView(
                                        recording: recording,
                                        viewModel: askSonoVM
                                    )
                                    .id(recording.id)
                                }
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 24) // normal breathing room; bottom bars handled by safeAreaInset
                        }
                    }
                }
                .coordinateSpace(name: "recordingDetailsScroll")
                .onTapGesture {
                    if isEditingTitle { saveTitleEdit() }
                }
                .onPreferenceChange(TopMarkerMinYPreferenceKey.self) { val in
                    topMarkerMinY = val
                    updateTopTitleVisibility()
                }
                .onPreferenceChange(HeaderHeightPreferenceKey.self) { val in
                    headerHeight = val
                    updateTopTitleVisibility()
                }
            }

            // Transcription progress overlay
            if recording.status == .inProgress {
                TranscriptionProgressOverlay(
                    progress: currentProgress,
                    isQueued: progressManager.isQueued(recordingId: recording.id),
                    queuePosition: progressManager.getOverallPosition(for: recording.id)
                )
            }
        }
        .background(Color.warmGray50.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .overlay(alignment: .top) {
            if showCopyToast {
                ToastView(message: "Copied transcription")
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }

        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if selectedTab == .transcript {
                    RecordingPlayerBar(
                        audioService: audioPlayback,
                        audioURL: recording.resolvedURL,
                        fullText: recording.fullText,
                        onCopyPressed: {
                            withAnimation { showCopyToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showCopyToast = false }
                            }
                        },
                        onSharePressed: {
                            if let url = recording.resolvedURL {
                                if let transcriptionFileURL = ShareHelper.createTranscriptionFile(recording.fullText, title: recording.title) {
                                    ShareHelper.shareItems([transcriptionFileURL, url])
                                } else {
                                    ShareHelper.shareTranscription(recording.fullText, title: recording.title)
                                }
                            } else {
                                ShareHelper.shareTranscription(recording.fullText, title: recording.title)
                            }
                        }
                    )
                    .background(Color.warmGray50)
                }

                if selectedTab == .askSono {
                    AskSonoInputBar(viewModel: askSonoVM)
                        .background(Color.warmGray50)
                }
            }
        }

        .sheet(isPresented: $showDeleteConfirm) {
            ConfirmationSheet(
                isPresented: $showDeleteConfirm,
                title: "Delete recording?",
                message: "Are you sure you want to delete \"\(recording.title)\"? This action cannot be undone.",
                confirmButtonText: "Delete recording",
                cancelButtonText: "Cancel",
                onConfirm: {
                    TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)
                    modelContext.delete(recording)
                    showDeleteConfirm = false
                    dismiss()
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

        .onAppear {
            selectedTab = .transcript

            let audioManager = AudioPlayerManager.shared
            if let currentGlobal = audioManager.currentRecording, currentGlobal.id != recording.id {
                audioManager.stop()
            }

            if let currentGlobal = audioManager.currentRecording, currentGlobal.id == recording.id {
                let wasPlaying = audioManager.player.isPlaying
                let currentTime = audioManager.player.currentTime
                audioManager.stop()

                if let url = recording.resolvedURL {
                    audioPlayback.preload(url: url)
                    audioPlayback.seek(to: currentTime)
                    if wasPlaying { audioPlayback.play() }
                }
            } else if let url = recording.resolvedURL {
                audioPlayback.preload(url: url)
            }

            audioManager.activeRecordingDetailsId = recording.id
        }

        .onDisappear {
            if isEditingTitle { saveTitleEdit() }
            audioPlayback.stop()
            AudioPlayerManager.shared.clearActiveRecordingDetails()
        }

        .onChange(of: progressManager.activeTranscriptions[recording.id]) { _, newProgress in
            if let progress = newProgress { currentProgress = progress }
        }

        .onChange(of: recording.status) { oldStatus, newStatus in
            if oldStatus == .inProgress && newStatus == .completed { currentProgress = 1.0 }
        }
    }

    // MARK: - Views

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TimeFormatter.dateWithTime(from: recording.recordedAt))
                .font(.dmSansMedium(size: 14))
                .foregroundColor(.warmGray400)

            if isEditingTitle {
                TextField("", text: $editedTitle)
                    .font(.dmSansSemiBold(size: 24))
                    .foregroundColor(.baseBlack)
                    .focused($isTitleFocused)
                    .submitLabel(.done)
                    .onSubmit { saveTitleEdit() }
            } else {
                Text(recording.title)
                    .font(.dmSansSemiBold(size: 24))
                    .foregroundColor(recording.title == "Untitled recording" ? .warmGray400 : .baseBlack)
                    .onTapGesture { startTitleEdit() }
            }

            CollectionTagsView(collections: recording.collections)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var tabsHeader: some View {
        HStack(spacing: 16) {
            TabButton(title: "Transcript", isSelected: selectedTab == .transcript) { selectedTab = .transcript }
            TabButton(title: "Summary", isSelected: selectedTab == .summary) { selectedTab = .summary }
            TabButton(title: "Ask Sono", isSelected: selectedTab == .askSono) { selectedTab = .askSono }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.warmGray50)
    }

    // MARK: - Helpers

    private func updateTopTitleVisibility() {
        guard headerHeight > 0 else { return }

        // header is gone once we've scrolled past its full height
        let headerGone = scrollOffset >= headerHeight - 4

        if headerGone != showTopTitle {
            withAnimation(.easeInOut(duration: 0.18)) {
                showTopTitle = headerGone
            }
        }
    }


    private func startTitleEdit() {
        editedTitle = recording.title == "Untitled recording" ? "" : recording.title
        isEditingTitle = true
        isTitleFocused = true
    }

    private func saveTitleEdit() {
        let trimmed = editedTitle.trimmed
        recording.title = trimmed.isEmpty ? "Untitled recording" : trimmed
        isEditingTitle = false
        isTitleFocused = false
    }
}

// MARK: - Preference Keys

private struct TopMarkerMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct HeaderHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Transcription Progress Overlay

private struct TranscriptionProgressOverlay: View {
    let progress: Double
    let isQueued: Bool
    let queuePosition: (position: Int, total: Int)?

    var body: some View {
        ZStack {
            Color.warmGray50.ignoresSafeArea()
            VStack(spacing: 0) {
                if isQueued {
                    VStack(spacing: 0) {
                        Text("Waiting to transcribe")
                            .font(.dmSansSemiBold(size: 24))
                            .foregroundColor(.baseBlack)
                            .multilineTextAlignment(.center)
                        Spacer().frame(height: 8)
                        Text("Your recording will be transcribed when the current transcription finishes.")
                            .font(.dmSansRegular(size: 16))
                            .foregroundColor(.warmGray700)
                            .multilineTextAlignment(.center)

                        if let qp = queuePosition {
                            Spacer().frame(height: 10)
                            Text("Queue \(qp.position) of \(qp.total)")
                                .font(.dmSansRegular(size: 14))
                                .foregroundColor(.warmGray500)
                        }
                    }
                    .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 0) {
                        Text("\(Int(progress * 100))%")
                            .font(.dmSansSemiBold(size: 64))
                            .foregroundColor(.baseBlack)
                        Spacer().frame(height: 8)
                        Text("Transcribing audio")
                            .font(.dmSansSemiBold(size: 24))
                            .foregroundColor(.baseBlack)
                            .multilineTextAlignment(.center)
                        Spacer().frame(height: 8)
                        Text("Transcription in progress. Please do not close.")
                            .font(.dmSansRegular(size: 16))
                            .foregroundColor(.warmGray700)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
