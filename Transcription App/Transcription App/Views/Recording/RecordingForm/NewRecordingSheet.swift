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
            customContent: {
                AnyView(
                    VStack(spacing: 1) {
                        NewRecordingActionButton(
                            iconName: "microphone",
                            title: "Record audio",
                            tint: .pink,
                            action: {
                                isPresented = false
                                onRecordAudio()
                            }
                        )

                        NewRecordingActionButton(
                            iconName: "file",
                            title: "Upload file",
                            tint: .teal,
                            action: {
                                isPresented = false
                                onUploadFile()
                            }
                        )

                        NewRecordingActionButton(
                            iconName: "video-camera",
                            title: "Upload video",
                            tint: .blue,
                            action: {
                                isPresented = false
                                onChooseFromPhotos()
                            }
                        )
                    }
                    .background(Color.baseWhite)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                )
            },
            isPresented: $isPresented
        )
    }
}

// MARK: - New Recording Action Button
private struct NewRecordingActionButton: View {
    let iconName: String
    let title: String
    let tint: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(tint)

                Text(title)
                    .font(.body)
                    .foregroundColor(.baseBlack)

                Spacer()
            }
            .padding()
            .background(Color.baseWhite)
        }
    }
}
