import SwiftUI

struct NewRecordingSheet: View {
    // MARK: - Callbacks
    var onRecordAudio: () -> Void
    var onUploadFile: () -> Void
    var onChooseFromPhotos: () -> Void
    @Binding var isPresented: Bool

    // MARK: - Body
    var body: some View {
        ActionSheet(
            actions: [
                ActionItem(
                    title: "Record audio",
                    icon: "microphone",
                    action: {
                        isPresented = false
                        onRecordAudio()
                    },
                    tintColor: .pink
                ),
                ActionItem(
                    title: "Upload file",
                    icon: "file",
                    action: {
                        isPresented = false
                        onUploadFile()
                    },
                    tintColor: .teal
                ),
                ActionItem(
                    title: "Upload video",
                    icon: "video-camera",
                    action: {
                        isPresented = false
                        onChooseFromPhotos()
                    },
                    tintColor: .blue
                )
            ],
            isPresented: $isPresented
        )
    }
}
