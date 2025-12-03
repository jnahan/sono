import SwiftUI
import SwiftData

struct RecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var folders: [Folder]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showTranscriptionDetail = false
    @State private var pendingAudioURL: URL? = nil
    
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
                        onLeftTap: { dismiss() }
                    )
                    
                    RecorderControl(onFinishRecording: { url in
                        print("=== RecorderControl finished with URL: \(url)")
                        pendingAudioURL = url
                        showTranscriptionDetail = true
                    })
                }
            }
            .navigationBarHidden(true)
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
                    folders: folders,
                    modelContext: modelContext,
                    onTranscriptionComplete: {
                        pendingAudioURL = nil
                        showTranscriptionDetail = false
                        dismiss()
                    }
                )
            }
        }
    }
}
