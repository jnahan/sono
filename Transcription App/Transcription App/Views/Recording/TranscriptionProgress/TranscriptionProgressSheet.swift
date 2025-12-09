import SwiftUI
import SwiftData

struct TranscriptionProgressSheet: View {
    let recording: Recording
    var onComplete: ((Recording) -> Void)? = nil
    @StateObject private var progressManager = TranscriptionProgressManager.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var transcriptionProgress: Double = 0.0
    @State private var transcriptionError: String?
    
    init(recording: Recording, onComplete: ((Recording) -> Void)? = nil) {
        self.recording = recording
        self.onComplete = onComplete
    }
    
    var body: some View {
        ZStack {
            Color.warmGray50
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Check if queued
                if progressManager.isQueued(recordingId: recording.id) {
                    // Queued state
                    Text("Waiting to transcribe")
                        .font(.custom("LibreBaskerville-Regular", size: 24))
                        .foregroundColor(.baseBlack)
                        .multilineTextAlignment(.center)
                    
                    Text("Your recording will be transcribed\nwhen the current transcription finishes")
                        .font(.system(size: 16))
                        .foregroundColor(.warmGray500)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                } else if transcriptionError == nil {
                    // Progress percentage (actively transcribing)
                    Text("\(Int(transcriptionProgress * 100))%")
                        .font(.custom("LibreBaskerville-Regular", size: 64))
                        .foregroundColor(.baseBlack)
                    
                    Text("Transcription in progress")
                        .font(.custom("LibreBaskerville-Regular", size: 24))
                        .foregroundColor(.baseBlack)
                        .multilineTextAlignment(.center)
                    
                    Text("Please do not close the app\nuntil transcription is complete")
                        .font(.system(size: 16))
                        .foregroundColor(.warmGray500)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                } else {
                    // Error state
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                        .padding(.bottom, 16)
                    
                    Text("Transcription Failed")
                        .font(.custom("LibreBaskerville-Regular", size: 24))
                        .foregroundColor(.baseBlack)
                    
                    Text(transcriptionError ?? "Unknown error")
                        .font(.system(size: 16))
                        .foregroundColor(.warmGray500)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Go Back")
                            .font(.custom("LibreBaskerville-Regular", size: 16))
                    }
                    .buttonStyle(AppButtonStyle())
                    .padding(.top, 24)
                }
                
                Spacer()
            }
            .padding(.horizontal, AppConstants.UI.Spacing.large)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Check if already completed when view appears
            if recording.status == .completed {
                transcriptionProgress = 1.0
                // Navigate to details immediately via callback
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    onComplete?(recording)
                }
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
            // When transcription completes, navigate to details
            if oldStatus == .inProgress && newStatus == .completed {
                transcriptionProgress = 1.0
                // Small delay to show 100%, then navigate
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    // Use callback to replace this view with RecordingDetailsView
                    onComplete?(recording)
                }
            } else if newStatus == .failed {
                transcriptionError = recording.failureReason ?? "Transcription failed"
            }
        }
    }
    
    // MARK: - Transcription
    
    private func startTranscription() {
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
                print("ℹ️ [TranscriptionProgressSheet] Recording was deleted, cannot start transcription")
                return
            }
            
            existingRecording.status = .inProgress
            existingRecording.transcriptionStartedAt = Date()
            existingRecording.failureReason = nil
            
            // Save initial status update
            do {
                try modelContext.save()
            } catch {
                print("⚠️ [TranscriptionProgressSheet] Failed to save initial status: \(error)")
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
                    print("ℹ️ [TranscriptionProgressSheet] Recording was deleted during transcription, skipping result update")
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
                    print("✅ [TranscriptionProgressSheet] Transcription completed successfully")
                } catch {
                    transcriptionProgress = 0.0
                    transcriptionError = "Failed to save transcription: \(error.localizedDescription)"
                    verifyRecording.status = .failed
                    verifyRecording.failureReason = transcriptionError
                    try? modelContext.save()
                    TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
                }
            } catch is CancellationError {
                print("ℹ️ [TranscriptionProgressSheet] Transcription cancelled for recording: \(recordingId.uuidString.prefix(8))")
                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            } catch {
                transcriptionProgress = 0.0
                
                // Check if recording still exists before updating error state
                let errorDescriptor = FetchDescriptor<Recording>(
                    predicate: #Predicate { r in
                        r.id == recordingId
                    }
                )
                
                if let errorRecordings = try? modelContext.fetch(errorDescriptor),
                   let errorRecording = errorRecordings.first {
                    transcriptionError = "Transcription failed: \(error.localizedDescription)"
                    errorRecording.status = .failed
                    errorRecording.failureReason = transcriptionError
                    try? modelContext.save()
                } else {
                    print("ℹ️ [TranscriptionProgressSheet] Recording was deleted, skipping error state update")
                }
                
                TranscriptionProgressManager.shared.completeTranscription(for: recordingId)
            }
        }
        
        // Register the task for cancellation
        TranscriptionProgressManager.shared.registerTask(for: recordingId, task: transcriptionTask)
    }
}
