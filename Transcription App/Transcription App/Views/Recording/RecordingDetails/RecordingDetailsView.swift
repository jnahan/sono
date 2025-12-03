import SwiftUI
import SwiftData
import AVFoundation

struct RecordingDetailsView: View {
    let recording: Recording
    @StateObject private var audioPlayer = AudioPlayerController()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var folders: [Folder]
    
    @State private var showShareSheet = false
    @State private var showNotePopup = false
    @State private var showEditRecording = false
    @State private var showDeleteConfirm = false
    @State private var showMenu = false
    
    var body: some View {
        ZStack {
            Color.warmGray50
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Top Bar
                CustomTopBar(
                    title: "",
                    leftIcon: "caret-left",
                    rightIcon: "dots-three",
                    onLeftTap: { dismiss() },
                    onRightTap: { showMenu = true }
                )
                
                // Header
                VStack(spacing: 12) {
                    Image("asterisk")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)

                    VStack(spacing: 8) {
                        Text(relativeDate)
                            .font(.system(size: 14))
                            .foregroundColor(.warmGray500)
                        
                        Text(recording.title)
                            .font(.custom("LibreBaskerville-Medium", size: 24))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                
                // Scrollable Transcript Area
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !recording.segments.isEmpty {
                            ForEach(recording.segments) { segment in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(formatTime(segment.start))
                                        .font(.system(size: 14))
                                        .foregroundColor(.warmGray400)
                                    
                                    Text(segment.text)
                                        .font(.system(size: 16))
                                        .foregroundColor(.baseBlack)
                                }
                            }
                        } else {
                            Text(recording.fullText)
                                .font(.system(size: 16))
                                .foregroundColor(.baseBlack)
                                .lineSpacing(4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 164)
                    }
                }
                
                Spacer()
            }
            
            // Audio Player Controls (Fixed at bottom)
            VStack {
                Spacer()
                
                AudioPlayerControls(
                    audioPlayer: audioPlayer,
                    audioURL: recording.resolvedURL,
                    fullText: recording.fullText,
                    onNotePressed: {
                        showNotePopup = true
                    },
                    onSharePressed: {
                        showShareSheet = true
                    }
                )
            }
            
            // Note Overlay
            if showNotePopup {
                NoteOverlay(
                    isPresented: $showNotePopup,
                    noteText: recording.notes
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showNotePopup)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Copy transcription") {
                UIPasteboard.general.string = recording.fullText
            }
            
            Button("Share transcription") {
                let activityVC = UIActivityViewController(activityItems: [recording.fullText], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.keyWindow?.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            }
            
            Button("Export audio") {
                if let url = recording.resolvedURL {
                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.keyWindow?.rootViewController {
                        rootVC.present(activityVC, animated: true)
                    }
                }
            }
            
            Button("Edit") {
                showEditRecording = true
            }
            
            Button("Delete", role: .destructive) {
                showDeleteConfirm = true
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = recording.resolvedURL {
                ShareSheet(items: [recording.fullText, url])
            } else {
                ShareSheet(items: [recording.fullText])
            }
        }
        .sheet(isPresented: $showEditRecording) {
            RecordingFormView(
                isPresented: $showEditRecording,
                audioURL: nil,
                existingRecording: recording,
                folders: folders,
                modelContext: modelContext,
                onTranscriptionComplete: {}
            )
        }
        .sheet(isPresented: $showDeleteConfirm) {
            DeleteRecordingConfirmation(
                isPresented: $showDeleteConfirm,
                recordingTitle: recording.title,
                onConfirm: {
                    modelContext.delete(recording)
                    showDeleteConfirm = false
                    dismiss()
                }
            )
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
    
    private var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(recording.recordedAt) {
            return "Today"
        } else if calendar.isDateInYesterday(recording.recordedAt) {
            return "Yesterday"
        } else {
            let components = calendar.dateComponents([.day], from: recording.recordedAt, to: now)
            if let days = components.day, days < 7 {
                return "\(days)d ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: recording.recordedAt)
            }
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
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Audio file missing at path:", url.path)
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            print("❌ Failed to load audio:", error)
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
