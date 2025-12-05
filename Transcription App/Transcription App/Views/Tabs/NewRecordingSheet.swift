import SwiftUI

struct NewRecordingSheet: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Callbacks
    var onRecordAudio: () -> Void
    var onLiveTranscription: () -> Void
    var onUploadFile: () -> Void
    var onChooseFromPhotos: () -> Void
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Background with blur
            Color.clear
                .background(.ultraThinMaterial)
                .background(Color.warmGray300.opacity(0.6))
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    closeButton
                    
                    actionButtons
                }
            }
        }
    }
    
    // MARK: - Subviews
    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 1) {
            ActionButton(
                iconName: "microphone",
                title: "Record audio",
                tint: .accent,
                action: {
                    dismiss()
                    onRecordAudio()
                }
            )
            
            Divider()
                .padding(.leading, 60)
            
            ActionButtonWithBadge(
                iconName: "waveform",
                title: "Live transcription",
                badge: "BETA",
                tint: .accent,
                action: {
                    dismiss()
                    onLiveTranscription()
                }
            )
            
            Divider()
                .padding(.leading, 60)
            
            ActionButton(
                iconName: "file",
                title: "Upload file",
                tint: .teal,
                action: {
                    dismiss()
                    onUploadFile()
                }
            )
            
            Divider()
                .padding(.leading, 60)
            
            ActionButton(
                iconName: "video-camera",
                title: "Upload video",
                tint: .blue,
                action: {
                    dismiss()
                    onChooseFromPhotos()
                }
            )
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .padding()
    }
}

// MARK: - Action Button
private struct ActionButton: View {
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
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        }
    }
}

// MARK: - Action Button with Badge
private struct ActionButtonWithBadge: View {
    let iconName: String
    let title: String
    let badge: String
    let tint: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(tint)

                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accent)
                    .cornerRadius(4)

                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        }
    }
}
