import SwiftUI
import SwiftData

struct RecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var collections: [Collection]
    @Environment(\.modelContext) private var modelContext
    
    // Configuration
    let isLiveTranscriptionEnabled: Bool
    
    @State private var showTranscriptionDetail = false
    @State private var pendingAudioURL: URL? = nil
    @State private var showExitConfirmation = false
    
    init(isLiveTranscriptionEnabled: Bool = false) {
        self.isLiveTranscriptionEnabled = isLiveTranscriptionEnabled
    }
    
    private var title: String {
        isLiveTranscriptionEnabled ? "Live Transcription" : "Recording"
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
                    HStack {
                        CustomTopBar(
                            title: title,
                            leftIcon: "x",
                            onLeftTap: { showExitConfirmation = true }
                        )
                    }
                    
                    // Beta badge for live transcription
                    if isLiveTranscriptionEnabled {
                        HStack {
                            Text("BETA")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accent)
                                .cornerRadius(4)
                        }
                        .padding(.top, 4)
                    }
                    
                    RecorderControl(
                        isLiveTranscriptionEnabled: isLiveTranscriptionEnabled,
                        onFinishRecording: { url in
                            print("=== RecorderControl finished with URL: \(url)")
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
        }
    }
}
