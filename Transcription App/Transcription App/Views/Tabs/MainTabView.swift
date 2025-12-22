import SwiftUI
import SwiftData
import UIKit
import AVFoundation

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Collection.name) private var collections: [Collection]
    @State private var tabBarLockedHidden = false

    @State private var selectedTab = 0

    @State private var showPlusButton = true

    @State private var isRecordingsRoot = true
    @State private var isCollectionsRoot = true

    @ObservedObject private var actionSheetManager = ActionSheetManager.shared

    @State private var showNewRecordingSheet = false
    @State private var showRecorderScreen = false
    @State private var showFilePicker = false
    @State private var showVideoPicker = false

    @State private var pendingAudioURL: URL?
    @State private var isExtractingAudio = false
    @State private var showExtractionError = false
    @State private var extractionErrorMessage = ""

    @State private var selectedRecordingForDetails: Recording?
    @State private var navigateToRecordingDetails = false

    private var shouldShowCustomTabBar: Bool {
        let isRootForSelectedTab: Bool = {
            switch selectedTab {
            case 0: return isRecordingsRoot
            case 1: return isCollectionsRoot
            default: return true
            }
        }()
        return isRootForSelectedTab && showPlusButton && !tabBarLockedHidden
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {

                NavigationStack {
                    RecordingsView(
                        tabBarLockedHidden: $tabBarLockedHidden,
                        showPlusButton: $showPlusButton,
                        isRoot: $isRecordingsRoot
                    )
                    .navigationDestination(isPresented: $navigateToRecordingDetails) {
                        if let recording = selectedRecordingForDetails {
                            RecordingDetailsView(recording: recording, onDismiss: {
                                navigateToRecordingDetails = false
                                selectedRecordingForDetails = nil
                            })
                            .onAppear {
                                tabBarLockedHidden = true
                            }
                            .onDisappear {
                                tabBarLockedHidden = false
                            }
                        }
                    }
                }
                .tabItem { EmptyView() }
                .tag(0)

                NavigationStack {
                    CollectionsView(
                        isRoot: $isCollectionsRoot
                    )
                }
                .tabItem { EmptyView() }
                .tag(1)
            }

            VStack {
                Spacer()

                if shouldShowCustomTabBar {
                    VStack(spacing: 0) {
                        HStack(spacing: 40) {
                            Button {
                                selectedTab = 0
                            } label: {
                                Image(selectedTab == 0 ? "house-fill" : "house")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(selectedTab == 0 ? .baseBlack : .warmGray400)
                                    .frame(width: 32, height: 32)
                            }

                            Button {
                                showNewRecordingSheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image("plus-bold")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 120, height: 48)
                                .background(Color.baseBlack)
                                .cornerRadius(32)
                            }

                            Button {
                                selectedTab = 1
                            } label: {
                                Image(selectedTab == 1 ? "folder-fill" : "folder")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(selectedTab == 1 ? .baseBlack : .warmGray400)
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(
                            Color.warmGray50
                                .ignoresSafeArea(edges: .bottom)
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.12), value: shouldShowCustomTabBar)
                }
            }

            if showNewRecordingSheet {
                NewRecordingSheet(
                    onRecordAudio: { showRecorderScreen = true },
                    onUploadFile: { showFilePicker = true },
                    onChooseFromPhotos: { showVideoPicker = true },
                    isPresented: $showNewRecordingSheet
                )
                .zIndex(1000)
            }

            if actionSheetManager.isPresented {
                DotsThreeSheet(
                    isPresented: $actionSheetManager.isPresented,
                    actions: actionSheetManager.actions
                )
                .zIndex(1000)
            }
        }
        .overlay(alignment: .top) {
            if showExtractionError {
                ErrorToastView(
                    message: extractionErrorMessage,
                    isPresented: $showExtractionError
                )
                .padding(.top, 8)
            }
        }
        .onAppear {
            let appearance = UITabBar.appearance()
            appearance.isHidden = true
            appearance.backgroundImage = UIImage()
            appearance.shadowImage = UIImage()
            appearance.backgroundColor = .clear
        }
        .fullScreenCover(isPresented: $showRecorderScreen) {
            RecorderView(
                onDismiss: {
                    showRecorderScreen = false
                },
                onSaveComplete: { recording in
                    // Navigate to recording details to show progress
                    selectedRecordingForDetails = recording
                    navigateToRecordingDetails = true
                }
            )
        }
        .sheet(isPresented: $showFilePicker) {
            MediaFilePicker(
                onFilePicked: { url, mediaType in
                    showFilePicker = false

                    if mediaType == .video {
                        Task {
                            isExtractingAudio = true
                            do {
                                let audioURL = try await AudioExtractor.extractAudio(from: url)
                                try? FileManager.default.removeItem(at: url)

                                await MainActor.run {
                                    isExtractingAudio = false
                                    handleMediaSave(audioURL: audioURL)
                                }
                            } catch {
                                try? FileManager.default.removeItem(at: url)

                                await MainActor.run {
                                    isExtractingAudio = false
                                    extractionErrorMessage = error.localizedDescription
                                    showExtractionError = true
                                }
                            }
                        }
                    } else {
                        handleMediaSave(audioURL: url)
                    }
                },
                onCancel: {
                    showFilePicker = false
                }
            )
        }
        .sheet(isPresented: $showVideoPicker) {
            PhotoVideoPicker(
                onMediaPicked: { url in
                    showVideoPicker = false

                    Task {
                        isExtractingAudio = true
                        do {
                            let audioURL = try await AudioExtractor.extractAudio(from: url)
                            try? FileManager.default.removeItem(at: url)

                            await MainActor.run {
                                isExtractingAudio = false
                                handleMediaSave(audioURL: audioURL)
                            }
                        } catch {
                            try? FileManager.default.removeItem(at: url)

                            await MainActor.run {
                                isExtractingAudio = false
                                extractionErrorMessage = error.localizedDescription
                                showExtractionError = true
                            }
                        }
                    }
                },
                onCancel: {
                    showVideoPicker = false
                }
            )
        }
    }

    // MARK: - Helper Methods

    /// Handle saving media (file/video upload) and navigate to details
    private func handleMediaSave(audioURL: URL) {
        Logger.info("MainTabView", "Handling media save for: \(audioURL.lastPathComponent)")

        // Create recording with default title (trimmed to max length)
        let filename = audioURL.deletingPathExtension().lastPathComponent
        let maxLength = 50 // AppConstants.Validation.maxTitleLength

        // For video extractions, clean up the filename
        var cleanFilename = filename
        if filename.contains("-audio-") {
            if let videoName = filename.components(separatedBy: "-audio-").first, !videoName.isEmpty {
                cleanFilename = videoName
            }
        }

        let title = String(cleanFilename.prefix(maxLength))

        let recording = Recording(
            title: title,
            fileURL: audioURL,
            fullText: "",
            language: "",
            summary: nil,
            segments: [],
            collections: [],
            recordedAt: Date(),
            transcriptionStatus: .notStarted,
            failureReason: nil,
            transcriptionStartedAt: nil
        )

        modelContext.insert(recording)

        do {
            try modelContext.save()
            Logger.success("MainTabView", "Recording saved successfully")

            // Mark transcription as started
            recording.status = .inProgress
            recording.transcriptionStartedAt = Date()
            try modelContext.save()

            // Start transcription asynchronously
            startTranscription(for: recording, audioURL: audioURL)

            // Navigate to recording details
            selectedTab = 0 // Switch to recordings tab
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000) // Small delay for tab switch
                selectedRecordingForDetails = recording
                navigateToRecordingDetails = true
            }
        } catch {
            Logger.error("MainTabView", "Failed to save recording: \(error.localizedDescription)")
        }
    }

    /// Start transcription for a recording
    private func startTranscription(for recording: Recording, audioURL: URL) {
        let recordingId = recording.id

        Task { @MainActor in
            do {
                Logger.info("MainTabView", "Starting transcription for recording: \(recordingId.uuidString.prefix(8))")

                let result = try await TranscriptionService.shared.transcribe(
                    audioURL: audioURL,
                    recordingId: recordingId
                ) { progress in
                    Task { @MainActor in
                        if !Task.isCancelled {
                            TranscriptionProgressManager.shared.updateProgress(
                                for: recordingId,
                                progress: progress
                            )
                        }
                    }
                }

                // Update recording with results
                let descriptor = FetchDescriptor<Recording>(
                    predicate: #Predicate { r in r.id == recordingId }
                )

                guard let recordings = try? modelContext.fetch(descriptor),
                      let rec = recordings.first else {
                    Logger.info("MainTabView", "Recording deleted during transcription")
                    TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
                    return
                }

                rec.fullText = result.text
                rec.language = result.language
                rec.status = .completed
                rec.failureReason = nil

                // Add segments
                rec.segments.removeAll()
                for segment in result.segments {
                    let recSegment = RecordingSegment(
                        start: segment.start,
                        end: segment.end,
                        text: segment.text
                    )
                    modelContext.insert(recSegment)
                    rec.segments.append(recSegment)
                }

                try modelContext.save()
                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
                Logger.success("MainTabView", "Transcription completed successfully")

            } catch {
                Logger.error("MainTabView", "Transcription failed: \(error.localizedDescription)")

                // Update recording to failed status
                let descriptor = FetchDescriptor<Recording>(
                    predicate: #Predicate { r in r.id == recordingId }
                )

                if let recordings = try? modelContext.fetch(descriptor),
                   let rec = recordings.first {
                    rec.status = .failed
                    rec.failureReason = "Transcription failed"
                    try? modelContext.save()
                }

                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            }
        }
    }
}
