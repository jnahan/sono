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
                    Text(formatTime(audioPlayer.currentTime))
                        .font(.system(size: 12))
                        .foregroundColor(.warmGray500)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(formatTime(audioPlayer.duration))
                        .font(.system(size: 12))
                        .foregroundColor(.warmGray500)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 20)
            
            // Bottom Action Buttons - Full width with spacing
            HStack(spacing: 0) {
                // Note button group (icon + text)
                Button {
                    onNotePressed()
                } label: {
                    HStack(spacing: 6) {
                        Image("note")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        Text("Note")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.warmGray500)
                }
                
                Spacer()
                
                // Center playback controls
                HStack(spacing: 20) {
                    // Rewind button
                    Button {
                        audioPlayer.skip(by: -15)
                    } label: {
                        Image("clock-counter-clockwise")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .foregroundColor(.warmGray700)
                    }
                    
                    // Play/Pause
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
                    
                    // Forward button
                    Button {
                        audioPlayer.skip(by: 15)
                    } label: {
                        Image("clock-clockwise")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .foregroundColor(.warmGray700)
                    }
                }
                
                Spacer()
                
                // Copy and Export buttons group
                HStack(spacing: 16) {
                    // Copy button
                    Button {
                        UIPasteboard.general.string = fullText
                    } label: {
                        Image("copy")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.warmGray500)
                    }
                    
                    // Export/Share button
                    Button {
                        onSharePressed()
                    } label: {
                        Image("export")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.warmGray500)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color.warmGray100)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
