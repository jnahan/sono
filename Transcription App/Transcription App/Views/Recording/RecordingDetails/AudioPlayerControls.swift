import SwiftUI

struct AudioPlayerControls: View {
    @ObservedObject var audioPlayer: Player
    let audioURL: URL?
    let fullText: String
    var onNotePressed: () -> Void
    var onSharePressed: () -> Void
    var onAIPressed: () -> Void
    
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
            .padding(.horizontal, 32)
            
            // Bottom Action Buttons - Evenly spaced
            HStack(spacing: 0) {
                // AI/Sparkle button - switches to Ask Sono tab (furthest left)
                IconButton(icon: "sparkle") {
                    onAIPressed()
                }
                
                Spacer()
                
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
                        .frame(width: 32, height: 32)
                        .foregroundColor(.baseBlack)
                }
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(Color.white)
                )
                .appShadow()
                
                Spacer()
                
                // Copy button
                IconButton(icon: "copy") {
                    UIPasteboard.general.string = fullText
                }
                
                Spacer()
                
                // Export/Share button
                IconButton(icon: "export") {
                    onSharePressed()
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
        .background(Color.warmGray100)
    }
}
