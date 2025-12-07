import SwiftUI

struct AudioPreviewBar: View {
    @ObservedObject var audioManager = AudioPlayerManager.shared
    
    var body: some View {
        if let recording = audioManager.currentRecording {
            VStack(spacing: 0) {
                Divider()
                    .background(Color.warmGray200)
                
                HStack(spacing: 16) {
                    // Recording Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recording.title)
                            .font(.interMedium(size: 16))
                            .foregroundColor(.baseBlack)
                            .lineLimit(1)
                        
                        Text("\(TimeFormatter.formatTimestamp(audioManager.player.currentTime)) / \(TimeFormatter.formatTimestamp(audioManager.player.duration))")
                            .font(.system(size: 12))
                            .foregroundColor(.warmGray500)
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    // Play/Pause button
                    Button {
                        if audioManager.player.isPlaying {
                            audioManager.pause()
                        } else {
                            audioManager.playRecording(recording)
                        }
                    } label: {
                        Image(audioManager.player.isPlaying ? "pause-fill" : "play-fill")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.baseBlack)
                    }
                    .buttonStyle(.plain)
                    
                    // Close button
                    Button {
                        audioManager.stop()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.warmGray500)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppConstants.UI.Spacing.large)
                .padding(.vertical, 12)
                .background(Color.warmGray100)
            }
        }
    }
}
