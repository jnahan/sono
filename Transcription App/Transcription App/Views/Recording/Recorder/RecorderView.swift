import SwiftUI
import SwiftData

struct RecorderView: View {
    let onDismiss: (() -> Void)?
    let onSaveComplete: ((Recording) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Collection.name) private var collections: [Collection]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var showExitConfirmation = false
    @State private var recorderControl: RecorderControlState = RecorderControlState()
    @State private var userCanceledRecording = false
    
    init(onDismiss: (() -> Void)? = nil, onSaveComplete: ((Recording) -> Void)? = nil) {
        self.onDismiss = onDismiss
        self.onSaveComplete = onSaveComplete
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Base color layer
                Color.accentLight
                    .ignoresSafeArea()
                
                // Content
                VStack(spacing: 0) {
                    CustomTopBar(
                        title: "Recording",
                        leftIcon: "x",
                        onLeftTap: { showExitConfirmation = true }
                    )

                    RecorderControl(
                        state: recorderControl,
                        onFinishRecording: { url in
                            handleRecordingComplete(audioURL: url)
                        }
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showExitConfirmation) {
                ConfirmationSheet(
                    isPresented: $showExitConfirmation,
                    title: "Exit recording?",
                    message: "Are you sure you want to exit? Your current recording session will be lost.",
                    confirmButtonText: "Exit",
                    cancelButtonText: "Continue recording",
                    onConfirm: {
                        // Mark that user explicitly canceled
                        userCanceledRecording = true

                        // Delete the recording file if it exists
                        if let fileURL = recorderControl.currentFileURL {
                            try? FileManager.default.removeItem(at: fileURL)
                            Logger.info("RecorderView", "Deleted recording file after user cancellation")
                        }

                        dismiss()
                    }
                )
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Handle app lifecycle transitions
                if newPhase == .background || newPhase == .inactive {
                    // App going to background - auto-save if needed
                    autoSaveRecordingIfNeeded()
                } else if newPhase == .active && oldPhase == .background {
                    // App returning to foreground from background
                    handleReturnFromBackground()
                }
            }
            .onChange(of: recorderControl.shouldAutoSave) { _, shouldSave in
                if shouldSave && !userCanceledRecording {
                    autoSaveRecordingIfNeeded()
                    recorderControl.shouldAutoSave = false
                }
            }
            .onDisappear {
                // Only auto-save if user didn't explicitly cancel
                if !userCanceledRecording {
                    // Final safety check - save if user navigates away
                    autoSaveRecordingIfNeeded()
                }
            }
        }
    }

    /// Handle app returning from background
    private func handleReturnFromBackground() {
        // Don't auto-save if user explicitly canceled
        guard !userCanceledRecording else { return }

        guard let fileURL = recorderControl.currentFileURL else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Logger.warning("RecorderView", "No recording file found on return from background")
            return
        }

        Logger.info("RecorderView", "Returned from background with recording file")

        // Check if recording was already saved to database
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { recording in
                recording.filePath.contains(fileURL.lastPathComponent)
            }
        )

        if let existingRecordings = try? modelContext.fetch(descriptor),
           !existingRecordings.isEmpty {
            Logger.info("RecorderView", "Recording already saved in database")
            // Recording already saved, UI should show check icon
            return
        }

        // Recording exists but not in database - auto-save it
        Logger.info("RecorderView", "Auto-saving recording after return from background")
        performAutoSave(fileURL: fileURL)
    }

    /// Handle recording completion - save and start transcription
    private func handleRecordingComplete(audioURL: URL) {
        Logger.info("RecorderView", "Handling recording completion for: \(audioURL.lastPathComponent)")

        // Create recording with default title
        let recording = Recording(
            title: "Untitled recording",
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
            Logger.success("RecorderView", "Recording saved successfully")

            // Mark transcription as started
            recording.status = .inProgress
            recording.transcriptionStartedAt = Date()
            try modelContext.save()

            // Start transcription asynchronously
            startTranscription(for: recording, audioURL: audioURL)

            // Notify parent with recording
            onSaveComplete?(recording)

            // Dismiss RecorderView after delay to prevent modal conflict
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
                onDismiss?()
            }
        } catch {
            Logger.error("RecorderView", "Failed to save recording: \(error.localizedDescription)")
        }
    }

    /// Start transcription for a recording
    private func startTranscription(for recording: Recording, audioURL: URL) {
        let recordingId = recording.id

        Task { @MainActor in
            do {
                Logger.info("RecorderView", "Starting transcription for recording: \(recordingId.uuidString.prefix(8))")

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
                    Logger.info("RecorderView", "Recording deleted during transcription")
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
                Logger.success("RecorderView", "Transcription completed successfully")

            } catch {
                Logger.error("RecorderView", "Transcription failed: \(error.localizedDescription)")

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

    /// Auto-save recording if there's an audio file but user hasn't finished
    private func autoSaveRecordingIfNeeded() {
        guard let fileURL = recorderControl.currentFileURL else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Logger.warning("RecorderView", "Audio file doesn't exist, skipping auto-save")
            return
        }

        // Check if this recording already exists in database
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { recording in
                recording.filePath.contains(fileURL.lastPathComponent)
            }
        )

        if let existingRecordings = try? modelContext.fetch(descriptor),
           !existingRecordings.isEmpty {
            Logger.info("RecorderView", "Recording already saved, skipping auto-save")
            return
        }

        Logger.info("RecorderView", "Auto-saving interrupted recording")
        performAutoSave(fileURL: fileURL)
    }

    /// Perform the actual auto-save operation
    private func performAutoSave(fileURL: URL) {
        // Create recording with notStarted status
        let recording = Recording(
            title: "Untitled recording",
            fileURL: fileURL,
            fullText: "",
            language: "",
            summary: nil,
            segments: [],
            collections: [],
            recordedAt: Date(),
            transcriptionStatus: .notStarted,
            failureReason: "Recording was interrupted. The app was closed before transcription could start.",
            transcriptionStartedAt: nil
        )

        modelContext.insert(recording)

        // Perform save operation asynchronously to avoid blocking main thread
        Task { @MainActor in
            do {
                try modelContext.save()
                Logger.success("RecorderView", "Auto-saved interrupted recording")
            } catch {
                Logger.error("RecorderView", "Failed to auto-save recording: \(error.localizedDescription)")
            }
        }
    }
}

// Observable state to share recorder state with parent
class RecorderControlState: ObservableObject {
    @Published var currentFileURL: URL? = nil
    @Published var shouldAutoSave: Bool = false
}
