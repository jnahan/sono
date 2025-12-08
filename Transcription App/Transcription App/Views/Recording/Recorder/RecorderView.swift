import SwiftUI
import SwiftData

struct RecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var collections: [Collection]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var showTranscriptionDetail = false
    @State private var pendingAudioURL: URL? = nil
    @State private var showExitConfirmation = false
    @State private var recorderControl: RecorderControlState = RecorderControlState()
    
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
        
        Task { @MainActor in
            _ = await RecordingAutoSaveService.autoSaveInterruptedRecording(
                fileURL: fileURL,
                modelContext: modelContext
            )
        }
    }
}

// Observable state to share recorder state with parent
class RecorderControlState: ObservableObject {
    @Published var currentFileURL: URL? = nil
    @Published var shouldAutoSave: Bool = false
}
