import SwiftUI
import SwiftData

struct RecorderView: View {
    let onDismiss: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Collection.name) private var collections: [Collection]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var showTranscriptionDetail = false
    @State private var pendingAudioURL: URL? = nil
    @State private var showExitConfirmation = false
    @State private var recorderControl: RecorderControlState = RecorderControlState()
    
    init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Base color layer
                Color.warmGray100
                    .ignoresSafeArea()
                
                // Gradient background - fill entire screen
                GeometryReader { geometry in
                    Image("gradient")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
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
                            pendingAudioURL = url
                            showTranscriptionDetail = true
                        }
                    )
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showExitConfirmation) {
                ConfirmationSheet(
                    isPresented: $showExitConfirmation,
                    title: "Exit recording?",
                    message: "Are you sure you want to exit? Your current recording session will be lost.",
                    confirmButtonText: "Exit",
                    cancelButtonText: "Continue recording",
                    onConfirm: {
                        dismiss()
                    }
                )
            }
            .fullScreenCover(item: Binding(
                get: { showTranscriptionDetail ? pendingAudioURL : nil },
                set: { newValue in
                    if newValue == nil {
                        showTranscriptionDetail = false
                        pendingAudioURL = nil
                    }
                }
            )) { audioURL in
                RecordingFormView(
                    isPresented: $showTranscriptionDetail,
                    audioURL: audioURL,
                    existingRecording: nil,
                    collections: collections,
                    modelContext: modelContext,
                    onTranscriptionComplete: {
                        pendingAudioURL = nil
                        showTranscriptionDetail = false
                        dismiss()
                    },
                    onExit: {
                        pendingAudioURL = nil
                        showTranscriptionDetail = false
                        dismiss()
                    },
                    onSaveComplete: { recording in
                        // Clear state - this will dismiss RecordingFormView's fullScreenCover
                        pendingAudioURL = nil
                        showTranscriptionDetail = false
                        // Then dismiss RecorderView to go back to home
                        // Use a small delay to ensure RecordingFormView dismisses first
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
                            onDismiss?()
                        }
                    }
                )
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Auto-save recording if app is backgrounded or terminated
                if newPhase == .background || newPhase == .inactive {
                    autoSaveRecordingIfNeeded()
                }
            }
            .onChange(of: recorderControl.shouldAutoSave) { _, shouldSave in
                if shouldSave {
                    autoSaveRecordingIfNeeded()
                    recorderControl.shouldAutoSave = false
                }
            }
            .onDisappear {
                // Final safety check - save if user navigates away
                autoSaveRecordingIfNeeded()
            }
        }
    }

    /// Auto-save recording if there's an audio file but user hasn't finished
    private func autoSaveRecordingIfNeeded() {
        guard let fileURL = recorderControl.currentFileURL else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ [RecorderView] Audio file doesn't exist, skipping auto-save")
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
            print("ℹ️ [RecorderView] Recording already saved, skipping auto-save")
            return
        }

        print("💾 [RecorderView] Auto-saving interrupted recording")

        // Create recording with notStarted status
        let recording = Recording(
            title: fileURL.deletingPathExtension().lastPathComponent,
            fileURL: fileURL,
            fullText: "",
            language: "",
            notes: "",
            summary: nil,
            segments: [],
            collection: nil,
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
                print("✅ [RecorderView] Auto-saved interrupted recording")
            } catch {
                print("❌ [RecorderView] Failed to auto-save recording: \(error)")
            }
        }
    }
}

// Observable state to share recorder state with parent
class RecorderControlState: ObservableObject {
    @Published var currentFileURL: URL? = nil
    @Published var shouldAutoSave: Bool = false
}
