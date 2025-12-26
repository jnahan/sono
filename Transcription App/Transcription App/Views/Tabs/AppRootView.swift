import SwiftUI
import SwiftData
import AVFoundation

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isRecordingsRoot = true

    @ObservedObject private var actionSheetManager = ActionSheetManager.shared

    @State private var showNewRecordingSheet = false
    @State private var showRecorderScreen = false
    @State private var showFilePicker = false
    @State private var showVideoPicker = false

    @State private var isExtractingAudio = false
    @State private var showExtractionError = false
    @State private var extractionErrorMessage = ""

    @State private var selectedRecordingForDetails: Recording?
    @State private var navigateToRecordingDetails = false

    @State private var currentCollectionFilter: CollectionFilter = .all

    var body: some View {
        ZStack {
            NavigationStack {
                RecordingsView(
                    isRoot: $isRecordingsRoot,
                    currentCollectionFilter: $currentCollectionFilter,
                    onAddRecording: {
                        showNewRecordingSheet = true
                    }
                )
                .navigationDestination(isPresented: $navigateToRecordingDetails) {
                    if let recording = selectedRecordingForDetails {
                        RecordingDetailsView(
                            recording: recording,
                            onDismiss: {
                                navigateToRecordingDetails = false
                                selectedRecordingForDetails = nil
                            }
                        )
                    }
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
        .fullScreenCover(isPresented: $showRecorderScreen) {
            RecorderView(
                onDismiss: { showRecorderScreen = false },
                onSaveComplete: { recording in
                    selectedRecordingForDetails = recording
                    navigateToRecordingDetails = true
                },
                collection: {
                    if case .collection(let c) = currentCollectionFilter {
                        return c
                    }
                    return nil
                }()
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
                onCancel: { showFilePicker = false }
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
                onCancel: { showVideoPicker = false }
            )
        }
    }

    // MARK: - Same helpers you already had

    private func handleMediaSave(audioURL: URL) {
        let filename = audioURL.deletingPathExtension().lastPathComponent
        let maxLength = 50

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

        // Add to collection if viewing a specific collection
        if case .collection(let collection) = currentCollectionFilter {
            recording.collections.append(collection)
        }

        do {
            try modelContext.save()

            recording.status = .inProgress
            recording.transcriptionStartedAt = Date()
            try modelContext.save()

            startTranscription(for: recording, audioURL: audioURL)

            // Jump to details
            selectedRecordingForDetails = recording
            navigateToRecordingDetails = true
        } catch {
            extractionErrorMessage = error.localizedDescription
            showExtractionError = true
        }
    }

    private func startTranscription(for recording: Recording, audioURL: URL) {
        let recordingId = recording.id

        Task { @MainActor in
            do {
                let result = try await TranscriptionService.shared.transcribe(
                    audioURL: audioURL,
                    recordingId: recordingId
                ) { progress in
                    Task { @MainActor in
                        if !Task.isCancelled {
                            TranscriptionProgressManager.shared.updateProgress(for: recordingId, progress: progress)
                        }
                    }
                }

                let descriptor = FetchDescriptor<Recording>(
                    predicate: #Predicate { r in r.id == recordingId }
                )

                guard let recordings = try? modelContext.fetch(descriptor),
                      let rec = recordings.first else {
                    TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
                    return
                }

                rec.fullText = result.text
                rec.language = result.language
                rec.status = .completed
                rec.failureReason = nil

                rec.segments.removeAll()
                for segment in result.segments {
                    let recSegment = RecordingSegment(start: segment.start, end: segment.end, text: segment.text)
                    modelContext.insert(recSegment)
                    rec.segments.append(recSegment)
                }

                try modelContext.save()
                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)

            } catch {
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
