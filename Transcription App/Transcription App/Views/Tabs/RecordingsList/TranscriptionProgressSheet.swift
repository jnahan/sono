import SwiftUI
import SwiftData

// MARK: - Reusable Status Display Component
private struct TranscriptionStatusView: View {
    let topText: String? // Optional percentage or nil
    let heading: String
    let description: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let topText = topText {
                Text(topText)
                    .font(.dmSansSemiBold(size: 64))
                    .foregroundColor(.baseBlack)

                Spacer()
                    .frame(height: 8)
            }

            Text(heading)
                .font(.dmSansSemiBold(size: 24))
                .foregroundColor(.baseBlack)
                .multilineTextAlignment(.center)

            Spacer()
                .frame(height: 8)

            Text(description)
                .font(.dmSansRegular(size: 16))
                .foregroundColor(.warmGray700)
                .multilineTextAlignment(.center)

            Spacer()
                .frame(height: 32)

            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(.dmSansRegular(size: 16))
            }
            .buttonStyle(AppButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
    }
}

struct TranscriptionProgressSheet: View {
    let recording: Recording
    var onComplete: ((Recording) -> Void)? = nil
    @StateObject private var progressManager = TranscriptionProgressManager.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var transcriptionProgress: Double = 0.0
    @State private var transcriptionError: String?
    @State private var wasBackgrounded = false
    
    init(recording: Recording, onComplete: ((Recording) -> Void)? = nil) {
        self.recording = recording
        self.onComplete = onComplete
    }
    
    private var isVideoFile: Bool {
        guard let url = recording.resolvedURL else { return false }
        let ext = url.pathExtension.lowercased()
        return ["mov", "mp4", "m4v", "avi", "mkv", "wmv", "flv"].contains(ext)
    }
    
    private var isExtracting: Bool {
        isVideoFile && transcriptionProgress == 0.0 && transcriptionError == nil
    }
    
    var body: some View {
        ZStack {
            Color.warmGray50
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Drag handle
                DragHandle()
                    .padding(.bottom, 24) // No top bar, so 24px spacing
                
                // Check if queued
                if progressManager.isQueued(recordingId: recording.id) {
                    TranscriptionStatusView(
                        topText: nil,
                        heading: "Waiting to transcribe",
                        description: "Your recording will be transcribed when the current transcription finishes.",
                        onDone: { dismiss() }
                    )
                } else if transcriptionError == nil {
                    if isExtracting {
                        TranscriptionStatusView(
                            topText: nil,
                            heading: "Extracting audio from video",
                            description: "Please do not close.",
                            onDone: { dismiss() }
                        )
                    } else {
                        TranscriptionStatusView(
                            topText: "\(Int(transcriptionProgress * 100))%",
                            heading: "Transcribing audio",
                            description: "Transcription in progress. Please do not close.",
                            onDone: { dismiss() }
                        )
                    }
                } else {
                    TranscriptionStatusView(
                        topText: nil,
                        heading: "Transcription failed",
                        description: transcriptionError ?? "Unknown error",
                        onDone: { dismiss() }
                    )
                }
            }
        }
        .presentationDetents([.height(transcriptionError == nil && progressManager.isQueued(recordingId: recording.id) == false ? 340 : 260)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.warmGray50)
        .presentationCornerRadius(16)
        .interactiveDismissDisabled(false)
        .onAppear {
            // Check if already completed when view appears
            if recording.status == .completed {
                transcriptionProgress = 1.0
                // Just dismiss the sheet, don't auto-navigate
                dismiss()
            } else if recording.status == .failed || recording.status == .notStarted {
                // Start transcription if not already in progress
                startTranscription()
            } else if recording.status == .inProgress {
                // Get initial progress if available
                if let progress = progressManager.getProgress(for: recording.id) {
                    transcriptionProgress = progress
                }
            }
        }
        .onChange(of: progressManager.activeTranscriptions[recording.id]) { _, newProgress in
            if let progress = newProgress {
                transcriptionProgress = progress
            }
        }
        .onChange(of: progressManager.queuePositions[recording.id]) { _, newPosition in
            // Queue position updated - UI will automatically reflect this
        }
        .onChange(of: progressManager.queuedRecordings) { _, _ in
            // Queue updated - UI will automatically reflect this
        }
        .onChange(of: recording.status) { oldStatus, newStatus in
            // When transcription completes, just dismiss
            if oldStatus == .inProgress && newStatus == .completed {
                transcriptionProgress = 1.0
                // Small delay to show 100%, then dismiss
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    dismiss()
                }
            } else if newStatus == .failed {
                transcriptionError = recording.failureReason ?? "Transcription failed"
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Handle app backgrounding during transcription
            if newPhase == .background && recording.status == .inProgress {
                Logger.info("TranscriptionProgressSheet", "App backgrounded during transcription")
                wasBackgrounded = true

                // Save current state - iOS will likely suspend the transcription task
                // The recording is already saved with .inProgress status
                // TranscriptionService task may be cancelled by iOS
            } else if newPhase == .active && oldPhase == .background && wasBackgrounded {
                Logger.info("TranscriptionProgressSheet", "App returned from background")
                wasBackgrounded = false

                // Check if transcription completed while backgrounded (unlikely but possible for short audio)
                if recording.status == .completed {
                    Logger.success("TranscriptionProgressSheet", "Transcription completed while backgrounded")
                    transcriptionProgress = 1.0
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: AppConstants.Transcription.modelWarmupWaitInterval)
                        onComplete?(recording)
                    }
                } else if recording.status == .inProgress {
                    // Check if transcription is still running
                    if !progressManager.hasActiveTranscription(for: recording.id) {
                        Logger.warning("TranscriptionProgressSheet", "Transcription was interrupted - restarting")
                        // Transcription was interrupted - restart it
                        startTranscription()
                    } else {
                        Logger.info("TranscriptionProgressSheet", "Transcription still running")
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            // Low memory warning - cancel transcription and save state
            if recording.status == .inProgress {
                Logger.warning("TranscriptionProgressSheet", "Low memory warning - canceling transcription")
                TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)

                // Update recording to allow resume
                recording.status = .inProgress
                recording.failureReason = ErrorMessages.Transcription.interruptedLowMemory
                try? modelContext.save()

                // Update UI
                transcriptionError = recording.failureReason
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            // App terminating - save current state
            if recording.status == .inProgress {
                Logger.warning("TranscriptionProgressSheet", "App terminating - saving state")
                recording.failureReason = ErrorMessages.Transcription.interrupted
                try? modelContext.save()
            }
        }
    }

    // MARK: - Transcription
    
    private func startTranscription() {
        // Prevent retrying failed recordings
        if recording.status == .failed {
            transcriptionError = ErrorMessages.Transcription.cannotRetranscribe
            return
        }

        guard let url = recording.resolvedURL else {
            transcriptionError = "Audio file not found"
            return
        }

        let recordingId = recording.id
        
        // Update recording status
        let transcriptionTask = Task { @MainActor in
            // Check if recording still exists before starting
            let descriptor = FetchDescriptor<Recording>(
                predicate: #Predicate { r in
                    r.id == recordingId
                }
            )
            
            guard let existingRecordings = try? modelContext.fetch(descriptor),
                  let existingRecording = existingRecordings.first else {
                Logger.info("TranscriptionProgressSheet", "Recording was deleted, cannot start transcription")
                return
            }
            
            existingRecording.status = .inProgress
            existingRecording.transcriptionStartedAt = Date()
            existingRecording.failureReason = nil
            
            // Save initial status update
            do {
                try modelContext.save()
            } catch {
                Logger.warning("TranscriptionProgressSheet", "Failed to save initial status: \(error.localizedDescription)")
            }
            
            // Start transcription
            do {
                let result = try await TranscriptionService.shared.transcribe(audioURL: url, recordingId: recordingId) { progress in
                    Task { @MainActor in
                        // Check if task was cancelled
                        if Task.isCancelled {
                            return
                        }
                        self.transcriptionProgress = progress
                        // Update shared progress manager for cross-view updates
                        TranscriptionProgressManager.shared.updateProgress(for: recordingId, progress: progress)
                    }
                }
                
                // Check if task was cancelled before processing results
                try Task.checkCancellation()
                
                // Verify recording still exists before updating
                let verifyDescriptor = FetchDescriptor<Recording>(
                    predicate: #Predicate { r in
                        r.id == recordingId
                    }
                )
                
                guard let verifyRecordings = try? modelContext.fetch(verifyDescriptor),
                      let verifyRecording = verifyRecordings.first else {
                    Logger.info("TranscriptionProgressSheet", ErrorMessages.Transcription.recordingDeletedDuringTranscription)
                    TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
                    return
                }
                
                // Update recording with transcription results
                verifyRecording.fullText = result.text
                verifyRecording.language = result.language
                verifyRecording.status = .completed
                verifyRecording.failureReason = nil
                
                // Clear existing segments and add new ones
                verifyRecording.segments.removeAll()
                for segment in result.segments {
                    let recordingSegment = RecordingSegment(
                        start: segment.start,
                        end: segment.end,
                        text: segment.text
                    )
                    modelContext.insert(recordingSegment)
                    verifyRecording.segments.append(recordingSegment)
                }
                
                // Save to database
                do {
                    try modelContext.save()
                    transcriptionProgress = 1.0
                    TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
                    Logger.success("TranscriptionProgressSheet", "Transcription completed successfully")
                } catch {
                    // Save error - keep as .inProgress so user can retry
                    transcriptionProgress = 0.0
                    transcriptionError = ErrorMessages.Transcription.interrupted
                    verifyRecording.status = .inProgress
                    verifyRecording.failureReason = transcriptionError
                    try? modelContext.save()
                    TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
                    Logger.warning("TranscriptionProgressSheet", "Save error handled gracefully: \(error.localizedDescription)")
                }
            } catch is CancellationError {
                // User cancelled or app was backgrounded - save as .inProgress for resume
                Logger.info("TranscriptionProgressSheet", "Transcription cancelled for recording: \(recordingId.uuidString.prefix(8))")

                // Update recording status to allow resume
                let cancelDescriptor = FetchDescriptor<Recording>(
                    predicate: #Predicate { r in
                        r.id == recordingId
                    }
                )

                if let cancelRecordings = try? modelContext.fetch(cancelDescriptor),
                   let cancelRecording = cancelRecordings.first {
                    cancelRecording.status = .inProgress
                    cancelRecording.failureReason = ErrorMessages.Transcription.interrupted
                    try? modelContext.save()
                }

                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            } catch {
                // All other errors - save as .inProgress so user can retry
                transcriptionProgress = 0.0

                // Check if recording still exists before updating error state
                let errorDescriptor = FetchDescriptor<Recording>(
                    predicate: #Predicate { r in
                        r.id == recordingId
                    }
                )

                if let errorRecordings = try? modelContext.fetch(errorDescriptor),
                   let errorRecording = errorRecordings.first {
                    transcriptionError = ErrorMessages.Transcription.failed
                    errorRecording.status = .failed
                    errorRecording.failureReason = transcriptionError
                    try? modelContext.save()
                    Logger.warning("TranscriptionProgressSheet", "Transcription failed: \(error.localizedDescription)")
                } else {
                    Logger.info("TranscriptionProgressSheet", "Recording was deleted, skipping error state update")
                }

                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            }
        }
        
        // Register the task for cancellation
        TranscriptionProgressManager.shared.registerTask(for: recordingId, task: transcriptionTask)
    }
}
