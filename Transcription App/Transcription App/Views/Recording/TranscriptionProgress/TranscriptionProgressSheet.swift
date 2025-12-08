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
                
                // Progress percentage
                if transcriptionError == nil {
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
            } else if recording.status == .failed {
                transcriptionError = recording.failureReason ?? "Transcription failed"
            } else {
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
}
