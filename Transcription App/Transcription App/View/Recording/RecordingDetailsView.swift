import SwiftUI
import SwiftData
import AVFoundation

struct RecordingDetailsView: View {
    let recording: Recording
    @StateObject private var audioPlayer = AudioPlayerController()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showShareSheet = false
    @State private var showNotePopup = false
    @State private var showEditTitle = false
    @State private var newTitle = ""
    @State private var showDeleteConfirm = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Scrollable Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title and Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recording.title)
                            .font(.system(size: 34, weight: .bold))
                        
                        Text(recording.recordedAt, style: .date)
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                    }
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
                
                // Bottom Action Buttons
                HStack(spacing: 40) {
                    // Note button
                    Button {
                        showNotePopup = true
                    } label: {
                        Image(systemName: "note.text")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Copy button
                    Button {
                        UIPasteboard.general.string = recording.fullText
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                    }
                    
                    // Share button
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
            .padding(.top, 16)
            .background(.ultraThinMaterial)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        if let url = recording.resolvedURL {
                            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootVC = windowScene.keyWindow?.rootViewController {
                                rootVC.present(activityVC, animated: true)
                            }
                        }
                    } label: {
                        Label("Export Audio", systemImage: "square.and.arrow.up.fill")
                    }
                    
                    Button {
                        showEditTitle = true
                        newTitle = recording.title
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = recording.resolvedURL {
                ShareSheet(items: [recording.fullText, url])
            } else {
                ShareSheet(items: [recording.fullText])
            }
        }
        .alert("Note", isPresented: $showNotePopup) {
            Button("OK", role: .cancel) {}
        } message: {
            if !recording.notes.isEmpty {
                Text(recording.notes)
            } else {
                Text("No notes")
            }
        }
        .alert("Edit Title", isPresented: $showEditTitle) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                recording.title = newTitle
            }
        }
        .alert("Delete Recording?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(recording)
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            if let url = recording.resolvedURL {
                audioPlayer.loadAudio(url: url)
            }
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
    
    func loadAudio(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            print("Failed to load audio: \(error)")
        }
    }
    
    func play(url: URL) {
        if player == nil {
            loadAudio(url: url)
        }
        player?.play()
        isPlaying = true
        startTimer()
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
