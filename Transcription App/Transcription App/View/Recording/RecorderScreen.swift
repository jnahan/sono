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
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    RecorderControl(onFinishRecording: { url in
                        print("=== RecorderControl finished with URL: \(url)")
                        pendingAudioURL = url
                        showTranscriptionDetail = true
                    })
                    
                    Spacer()
                }
            }
            .navigationTitle("Record Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
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
                CreateRecordingView(
                    isPresented: $showTranscriptionDetail,
                    audioURL: audioURL,
                    folders: folders,
                    modelContext: modelContext,
                    onTranscriptionComplete: {
                        pendingAudioURL = nil
                        showTranscriptionDetail = false
                        dismiss() // Go back to main view after saving
                    }
                )
            }
        }
        .navigationViewStyle(.stack) // Force single column on iPad
    }
}
