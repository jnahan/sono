//
//  RecordingDetailsView.swift
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

enum RecordingDetailTab {
    case transcript
    case summary
    case askSono
}

struct RecordingDetailsView: View {
    let recording: Recording
    var onDismiss: (() -> Void)? = nil

    @StateObject private var audioPlayback = AudioPlaybackService()
    @StateObject private var progressManager = TranscriptionProgressManager.shared
    @StateObject private var askSonoVM: AskSonoViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Collection.name) private var collections: [Collection]

    init(recording: Recording, onDismiss: (() -> Void)? = nil) {
        self.recording = recording
        self.onDismiss = onDismiss
        _askSonoVM = StateObject(wrappedValue: AskSonoViewModel(recording: recording))
    }

    @State private var showDeleteConfirm = false
    @State private var showCollectionPicker = false
    @State private var selectedTab: RecordingDetailTab = .transcript
    @State private var currentProgress: Double = 0.0

    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @FocusState private var isTitleFocused: Bool

    @State private var showCopyToast = false

    // scroll/title behavior
    @State private var headerHeight: CGFloat = 0
    @State private var scrollY: CGFloat = 0
    @State private var showTopTitle: Bool = false

    @State private var askSonoActivationToken = UUID()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                CustomTopBar(
                    title: showTopTitle ? recording.title : "",
                    leftIcon: "caret-left",
                    rightIcon: "dots-three-bold",
                    onLeftTap: { if let onDismiss { onDismiss() } else { dismiss() } },
                    onRightTap: {
                        HapticFeedback.light()
                        RecordingDetailsActionMenu.show(
                            recording: recording,
                            onShowCollectionPicker: { showCollectionPicker = true },
                            onShowDeleteConfirm: { showDeleteConfirm = true },
                            onShowCopyToast: {
                                ToastHelper.show($showCopyToast)
                            }
                        )
                    }
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {

                            headerView
                                .id("header")
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear {
                                                headerHeight = geo.size.height
                                                updateTopTitleVisibility()
                                            }
                                            .onChange(of: geo.size.height) { _, h in
                                                headerHeight = h
                                                updateTopTitleVisibility()
                                            }
                                    }
                                )

                            Section(
                                header: RecordingDetailsTabsHeader(
                                    selectedTab: selectedTab,
                                    onSelect: { selectedTab = $0 }
                                )
                            ) {
                                contentForSelectedTab
                                    .padding(.top, 12)
                                    .padding(.bottom, 24)
                            }
                        }
                        .background(
                            ScrollOffsetReader(
                                onScrollViewFound: { _ in },
                                onOffsetChange: { y in
                                    scrollY = y
                                    updateTopTitleVisibility()
                                }
                            )
                            .frame(width: 0, height: 0)
                        )
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture { if isEditingTitle { saveTitleEdit() } }

                    // Ask Sono auto-scroll (parent-owned)
                    .onAppear {
                        if selectedTab == .askSono {
                            scrollAskSonoToBottom(proxy, animated: false)
                        }
                    }
                    .onChange(of: askSonoActivationToken) { _, _ in
                        if selectedTab == .askSono {
                            scrollAskSonoToBottom(proxy, animated: false)
                        }
                    }
                    .onChange(of: askSonoVM.messages.count) { _, _ in
                        if selectedTab == .askSono {
                            scrollAskSonoToBottom(proxy, animated: true)
                        }
                    }
                    .onChange(of: askSonoVM.isProcessing) { _, processing in
                        if selectedTab == .askSono, !processing {
                            scrollAskSonoToBottom(proxy, animated: true)
                        }
                    }
                    .onChange(of: askSonoVM.streamingText) { _, _ in
                        if selectedTab == .askSono {
                            scrollAskSonoToBottom(proxy, animated: false)
                        }
                    }
                    .onChange(of: selectedTab) { _, newTab in
                        // Reset scroll position when switching tabs
                        switch newTab {
                        case .transcript, .summary:
                            // Scroll to top for transcript and summary
                            proxy.scrollTo("header", anchor: .top)
                        case .askSono:
                            // Scroll to bottom if messages exist, otherwise scroll to top
                            if askSonoVM.messages.isEmpty {
                                proxy.scrollTo("header", anchor: .top)
                            } else {
                                scrollAskSonoToBottom(proxy, animated: false)
                            }
                        }
                    }
                }
            }

            if recording.status == .inProgress {
                TranscriptionProgressOverlay(
                    progress: currentProgress,
                    isQueued: progressManager.isQueued(recordingId: recording.id),
                    queuePosition: progressManager.getOverallPosition(for: recording.id),
                    onDismiss: { if let onDismiss { onDismiss() } else { dismiss() } }
                )
            }
        }
        .background(Color.white.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .overlay(alignment: .top) {
            if showCopyToast {
                ToastView(message: "Copied transcription")
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBars }
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
        .onChange(of: selectedTab) { _, newTab in
            scrollY = 0
            showTopTitle = false
            updateTopTitleVisibility()

            if newTab == .askSono {
                askSonoActivationToken = UUID()
            }
        }
        .onAppear {
            showTopTitle = false
            selectedTab = .transcript
            setupAudioOnAppear()

            // Initialize current progress from progress manager
            if let progress = progressManager.getProgress(for: recording.id) {
                currentProgress = progress
            }

            #if canImport(UIKit)
            // Prevent display from turning off during transcription
            if recording.status == .inProgress {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            #endif
        }
        .onDisappear {
            if isEditingTitle { saveTitleEdit() }
            audioPlayback.stop()
            AudioPlayerManager.shared.clearActiveRecordingDetails()

            #if canImport(UIKit)
            // Ensure idle timer is always restored when view disappears
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
        .onChange(of: progressManager.activeTranscriptions[recording.id]) { _, newProgress in
            if let progress = newProgress { currentProgress = progress }
        }
        .onChange(of: recording.status) { oldStatus, newStatus in
            if oldStatus == .inProgress && newStatus == .completed {
                currentProgress = 1.0
                HapticFeedback.success()
            } else if newStatus == .failed {
                HapticFeedback.error()
            }

            #if canImport(UIKit)
            // Disable idle timer when transcription starts
            if oldStatus != .inProgress && newStatus == .inProgress {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            // Re-enable display auto-lock when transcription ends (completed or failed)
            else if oldStatus == .inProgress && newStatus != .inProgress {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            #endif
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TimeFormatter.dateWithTime(from: recording.recordedAt))
                .font(.dmSansMedium(size: 14))
                .foregroundColor(.blueGray400)

            if isEditingTitle {
                TextField("", text: $editedTitle)
                    .font(.dmSansSemiBold(size: 24))
                    .foregroundColor(.black)
                    .focused($isTitleFocused)
                    .submitLabel(.done)
                    .onSubmit { saveTitleEdit() }
            } else {
                Text(recording.title)
                    .font(.dmSansSemiBold(size: 24))
                    .foregroundColor(recording.title == "Untitled recording" ? .blueGray400 : .black)
                    .onTapGesture { startTitleEdit() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Tab Content

    private var contentForSelectedTab: some View {
        Group {
            switch selectedTab {
            case .transcript:
                TranscriptView(recording: recording, audioPlayback: audioPlayback)
                    .id(recording.id)
            case .summary:
                SummaryView(recording: recording)
            case .askSono:
                AskSonoView(recording: recording, viewModel: askSonoVM)
            }
        }
    }

    // MARK: - Bottom Bars

    private var bottomBars: some View {
        VStack(spacing: 0) {
            if selectedTab == .transcript && recording.status != .inProgress {
                RecordingPlayerBar(
                    audioService: audioPlayback,
                    audioURL: recording.resolvedURL,
                    fullText: recording.fullText,
                    onCopyPressed: {
                        HapticFeedback.success()
                        ToastHelper.show($showCopyToast)
                    },
                    onSharePressed: {
                        HapticFeedback.light()
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
                .background(Color.white)
            }

            if selectedTab == .askSono {
                // Keep YOUR existing input styling file; the only required change is its send action uses Task { await ... }
                AskSonoInputBar(viewModel: askSonoVM)
                    .background(Color.white)
            }
        }
    }

    // MARK: - Helpers

    private func scrollAskSonoToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(AskSonoView.bottomAnchorId, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(AskSonoView.bottomAnchorId, anchor: .bottom)
            }
        }
    }

    private func updateTopTitleVisibility() {
        guard headerHeight > 1 else { return }
        let shouldShow = scrollY >= (headerHeight - 4)
        if shouldShow != showTopTitle {
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.18)) { showTopTitle = shouldShow }
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

    private func setupAudioOnAppear() {
        let audioManager = AudioPlayerManager.shared
        let currentGlobal = audioManager.currentRecording

        // Stop playback if different recording
        if let currentGlobal, currentGlobal.id != recording.id {
            audioManager.stop()
            preloadCurrentRecording()
            audioManager.activeRecordingDetailsId = recording.id
            return
        }

        // Transfer state if same recording
        if let currentGlobal, currentGlobal.id == recording.id {
            transferPlaybackState(from: audioManager)
            audioManager.activeRecordingDetailsId = recording.id
            return
        }

        // Default: just preload
        preloadCurrentRecording()
        audioManager.activeRecordingDetailsId = recording.id
    }

    private func preloadCurrentRecording() {
        guard let url = recording.resolvedURL else { return }
        audioPlayback.preload(url: url)
    }

    private func transferPlaybackState(from manager: AudioPlayerManager) {
        let wasPlaying = manager.player.isPlaying
        let currentTime = manager.player.currentTime
        manager.stop()

        guard let url = recording.resolvedURL else { return }
        audioPlayback.preload(url: url)
        audioPlayback.seek(to: currentTime)
        if wasPlaying { audioPlayback.play() }
    }

    // MARK: - Tabs Header

    private struct RecordingDetailsTabsHeader: View {
        let selectedTab: RecordingDetailTab
        let onSelect: (RecordingDetailTab) -> Void

        var body: some View {
            HStack(spacing: 16) {
                TabButton(title: "Transcript", isSelected: selectedTab == .transcript) { onSelect(.transcript) }
                TabButton(title: "Summary", isSelected: selectedTab == .summary) { onSelect(.summary) }
                TabButton(title: "Ask Sono", isSelected: selectedTab == .askSono) { onSelect(.askSono) }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Color.white)
        }
    }
}
