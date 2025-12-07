import SwiftUI

struct AudioPlayerControls: View {
    @ObservedObject var audioPlayer: Player
    let audioURL: URL?
    let fullText: String
    var onNotePressed: () -> Void
    var onSharePressed: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            VStack(spacing: 12) {
                CustomSlider(
                    value: Binding(
                        get: { audioPlayer.currentTime },
                        set: { newTime in
                            audioPlayer.seek(toTime: newTime)
                        }
                    ),
                    range: 0...max(audioPlayer.duration, 0.1)
                ) { editing in
                    // Seeking is handled in the setter above
                }
                
                HStack {
                    Text(TimeFormatter.formatTimestamp(audioPlayer.currentTime))
                        .font(.system(size: 12))
                        .foregroundColor(.warmGray500)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(TimeFormatter.formatTimestamp(audioPlayer.duration))
                        .font(.system(size: 12))
                        .foregroundColor(.warmGray500)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, AppConstants.UI.Spacing.large)
            
            // Bottom Action Buttons - Full width with spacing
            HStack(spacing: 0) {
                // Note button
                IconButton(icon: "note") {
                    onNotePressed()
                }
                
                Spacer()
                
                // Center playback controls - Play/Pause only
                Button {
                    if let url = audioURL {
                        audioPlayer.play(url)
                    }
                } label: {
                    Image(audioPlayer.isPlaying ? "pause-fill" : "play-fill")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .foregroundColor(.baseBlack)
                }
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.white)
                )
                .appShadow()
                
                Spacer()
                
                // Copy and Share buttons group
                HStack(spacing: 16) {
                    // Copy button
                    IconButton(icon: "copy") {
                        UIPasteboard.general.string = fullText
                    }
                    
                    // Export/Share button
                    IconButton(icon: "export") {
                        onSharePressed()
                    }
                }
            }
            .padding(.horizontal, AppConstants.UI.Spacing.large)
            .padding(.bottom, 28)
        }
        .background(Color.warmGray100)
    }
}
