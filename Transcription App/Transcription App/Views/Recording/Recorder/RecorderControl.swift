import SwiftUI
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - RecorderControl
struct RecorderControl: View {
    @StateObject private var rec = Recorder()
    @StateObject private var player = Player()
    @StateObject private var liveTranscription = LiveTranscriptionService()
    @State private var micDenied = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var frozenMeterHistory: [Float] = []  // Freeze history when recording stops
    @State private var frozenTranscription: String = ""  // Freeze transcription when recording stops
    
    // Configuration
    let isLiveTranscriptionEnabled: Bool
    var onFinishRecording: ((URL) -> Void)?
    
    init(isLiveTranscriptionEnabled: Bool = false, onFinishRecording: ((URL) -> Void)? = nil) {
        self.isLiveTranscriptionEnabled = isLiveTranscriptionEnabled
        self.onFinishRecording = onFinishRecording
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Live transcription display at top (only when enabled)
                if isLiveTranscriptionEnabled {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                // Show loading state when model is not ready
                                if liveTranscription.isLoadingModel {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Loading model...")
                                            .font(.custom("Inter-Regular", size: 18))
                                            .foregroundColor(.warmGray400)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                } else if !liveTranscription.isModelLoaded && !rec.isRecording && frozenTranscription.isEmpty {
                                    Text("Preparing...")
                                        .font(.custom("Inter-Regular", size: 18))
                                        .foregroundColor(.warmGray400)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    // Show frozen transcription when stopped, live when recording
                                    let displayText = rec.isRecording ? 
                                        (liveTranscription.confirmedText + liveTranscription.hypothesisText) : 
                                        frozenTranscription
                                    
                                    if !displayText.isEmpty {
                                        HStack(alignment: .top, spacing: 0) {
                                            if rec.isRecording {
                                                // Show confirmed text in normal color
                                                Text(liveTranscription.confirmedText)
                                                    .font(.custom("Inter-Regular", size: 18))
                                                    .foregroundColor(.baseBlack)
                                                
                                                // Show hypothesis text in lighter color
                                                Text(liveTranscription.hypothesisText)
                                                    .font(.custom("Inter-Regular", size: 18))
                                                    .foregroundColor(.warmGray400)
                                            } else {
                                                Text(displayText)
                                                    .font(.custom("Inter-Regular", size: 18))
                                                    .foregroundColor(.baseBlack)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id("transcriptionEnd")
                                    } else if rec.isRecording {
                                        Text("Listening...")
                                            .font(.custom("Inter-Regular", size: 18))
                                            .foregroundColor(.warmGray400)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                        }
                        .frame(maxHeight: geometry.size.height * 0.35)
                        .onChange(of: liveTranscription.confirmedText + liveTranscription.hypothesisText) { _, _ in
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("transcriptionEnd", anchor: .bottom)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Timer display and waveform section
                VStack(spacing: 0) {
                    Text(TimeFormatter.formatTimestamp(elapsedTime))
                        .font(.interMedium(size: 14))
                        .foregroundColor(.warmGray700)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(32)
                    
                    ZStack(alignment: .top) {
                        // Waveform visualizer - show frozen history if stopped, live if recording
                        HStack(spacing: 0) {
                            RecorderVisualizer(
                                values: frozenMeterHistory.isEmpty ? rec.meterHistory : frozenMeterHistory,
                                barCount: 40
                            )
                            .frame(height: 80)
                            .clipped()
                            
                            Spacer()
                                .frame(width: 3)  // Exact width of white line
                        }
                        .frame(width: geometry.size.width / 2)
                        .padding(.top, 80)
                        .offset(x: -geometry.size.width / 4)
                        
                        // Vertical line on top - centered and fully opaque
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 3, height: 240)
                    }
                }
                
                Spacer()
                
                // Bottom buttons - 64px from bottom including safe area
                HStack(spacing: 24) {
                    // Retry button - only visible when recording is stopped (not during recording)
                    if !rec.isRecording && rec.fileURL != nil {
                        Button {
                            playTapHaptic()
                            resetRecording()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 20))
                                Text("Retry")
                                    .font(.system(size: 17, weight: .medium))
                            }
                            .foregroundColor(.accent)
                        }
                    } else {
                        // Invisible placeholder to maintain spacing
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20))
                            Text("Retry")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(.clear)
                    }
                    
                    // Record/Stop/Done button - changes based on state
                    Button {
                        playTapHaptic()
                        if rec.isRecording {
                            stopRecording()
                        } else if rec.fileURL == nil {
                            startRecording()
                        } else {
                            finishRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 72, height: 72)
                                .appShadow()
                            
                            if liveTranscription.isLoadingModel && isLiveTranscriptionEnabled {
                                // Loading model: show progress
                                ProgressView()
                                    .scaleEffect(1.2)
                            } else if rec.isRecording {
                                // Recording: red square
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accent)
                                    .frame(width: 24, height: 24)
                            } else if rec.fileURL == nil {
                                // Not started: red circle
                                Circle()
                                    .fill(Color.accent)
                                    .frame(width: 48, height: 48)
                            } else {
                                // Recorded: checkmark
                                Image("check")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .disabled(isLiveTranscriptionEnabled && liveTranscription.isLoadingModel)
                    
                    // Invisible spacer for balance
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20))
                        Text("Retry")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(.clear)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 64)
            }
        }
        .task {
            rec.requestPermission { ok in
                micDenied = (ok == false)
            }
            // Preload model for faster live transcription (only when enabled)
            if isLiveTranscriptionEnabled {
                try? await liveTranscription.preloadModel()
            }
        }
        .onChange(of: rec.isRecording) { _, isRecording in
            if isRecording {
                startTimer()
                frozenMeterHistory = []  // Clear frozen history when starting new recording
            } else {
                stopTimer()
            }
        }
        .alert("Microphone Access Needed", isPresented: $micDenied) {
            Button("OK", role: .cancel) {}
            #if canImport(UIKit)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            #endif
        } message: {
            Text("Please allow microphone access in Settings to record audio.")
        }
    }
    
    // MARK: - Actions
    private func startRecording() {
        player.stop()
        elapsedTime = 0
        frozenTranscription = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            rec.start()
            // Start live transcription if enabled
            if isLiveTranscriptionEnabled {
                Task {
                    do {
                        try await liveTranscription.startTranscription()
                    } catch {
                        print("Live transcription error: \(error)")
                    }
                }
            }
        }
    }
    
    private func stopRecording() {
        frozenMeterHistory = rec.meterHistory
        if isLiveTranscriptionEnabled {
            frozenTranscription = liveTranscription.getFinalTranscription()
            liveTranscription.stopTranscription()
        }
        rec.stop()
    }
    
    private func resetRecording() {
        rec.reset()
        if isLiveTranscriptionEnabled {
            liveTranscription.reset()
            frozenTranscription = ""
        }
        elapsedTime = 0
        frozenMeterHistory = []
    }
    
    private func finishRecording() {
        if rec.isRecording {
            if isLiveTranscriptionEnabled {
                frozenTranscription = liveTranscription.getFinalTranscription()
                liveTranscription.stopTranscription()
            }
            rec.stop()
        }
        if let fileURL = rec.fileURL {
            onFinishRecording?(fileURL)
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            elapsedTime += 0.01
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func playTapHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}
