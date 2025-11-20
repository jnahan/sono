import SwiftUI
import SwiftData
import AVFoundation

struct RecordingDetailView: View {
    let recording: Recording
    @StateObject private var audioPlayer = AudioPlayerController()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showShareSheet = false
    @State private var showMenu = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button {
                    showMenu = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding()
            
            // Scrollable Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    Text(recording.title)
                        .font(.system(size: 34, weight: .bold))
                        .padding(.horizontal)
                    
                    // Transcription with timestamps
                    if !recording.segments.isEmpty {
                        ForEach(recording.segments) { segment in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(formatTime(segment.start))
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                Text(segment.text)
                                    .font(.system(size: 17))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    } else {
                        // Fallback to full text if no segments
                        Text(recording.fullText)
                            .font(.system(size: 17))
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 200) // Space for player controls
            }
            
            Spacer()
            
            // Audio Player Controls (Fixed at bottom)
            VStack(spacing: 16) {
                // Progress Bar
                VStack(spacing: 8) {
                    Slider(value: $audioPlayer.currentTime, in: 0...audioPlayer.duration) { editing in
                        if !editing {
                            audioPlayer.seek(to: audioPlayer.currentTime)
                        }
                    }
                    .tint(.primary)
                    
                    HStack {
                        Text(formatTime(audioPlayer.currentTime))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatTime(audioPlayer.duration))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Playback Controls
                HStack(spacing: 60) {
                    // Rewind 15 seconds
                    Button {
                        audioPlayer.skip(by: -15)
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 32))
                            .foregroundColor(.primary)
                    }
                    
                    // Play/Pause
                    Button {
                        if audioPlayer.isPlaying {
                            audioPlayer.pause()
                        } else {
                            if let url = recording.resolvedURL {
                                audioPlayer.play(url: url)
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.primary)
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .offset(x: audioPlayer.isPlaying ? 0 : 2)
                        }
                    }
                    
                    // Forward 15 seconds
                    Button {
                        audioPlayer.skip(by: 15)
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 32))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.top, 16)
            .background(.ultraThinMaterial)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            if let url = recording.resolvedURL {
                ShareSheet(items: [recording.fullText, url])
            } else {
                ShareSheet(items: [recording.fullText])
            }
        }
        .confirmationDialog("Options", isPresented: $showMenu) {
            Button("Copy Transcription") {
                UIPasteboard.general.string = recording.fullText
            }
            
            Button("Share Transcription") {
                showShareSheet = true
            }
            
            Button("Export Audio") {
                // Export audio logic
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Player Controller
class AudioPlayerController: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    func play(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            player?.play()
            isPlaying = true
            startTimer()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        player?.stop()
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }
    
    func skip(by seconds: TimeInterval) {
        let newTime = max(0, min(duration, currentTime + seconds))
        seek(to: newTime)
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTime = player.currentTime
            
            if !player.isPlaying && self.isPlaying {
                self.isPlaying = false
                self.stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Recording.self, RecordingSegment.self, configurations: config)
    
    let recording = Recording(
        title: "Afternoon recording",
        fileURL: URL(fileURLWithPath: "/path/to/audio.m4a"),
        filePath: nil,
        fullText: "Lorem ipsum dolor sit amet consectetur.",
        language: "en",
        segments: [
            RecordingSegment(start: 92, end: 120, text: "Lorem ipsum dolor sit amet consectetur. Suspendisse quis cursus vitae blandit convallis suspendisse gravida at. Orci ac diam condimentum mi at. Metus consectetur consequat sapien hac morbi consectetur adipiscing donec. Feugiat cras enim tortor libero dignissim non adipiscing velit velit"),
            RecordingSegment(start: 92, end: 120, text: "Lorem ipsum dolor sit amet consectetur. Suspendisse quis cursus vitae blandit convallis suspendisse gravida at. Orci ac diam condimentum mi at. Metus consectetur consequat sapien hac morbi consectetur adipiscing donec. Feugiat cras enim tortor libero dignissim non adipiscing velit velit")
        ],
        recordedAt: Date()
    )
    
    container.mainContext.insert(recording)
    
    return RecordingDetailView(recording: recording)
        .modelContainer(container)
}
