import SwiftUI
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - RecorderControl
struct RecorderControl: View {
    @StateObject private var rec = Recorder()
    @StateObject private var player = AudioPlaybackService()
    @ObservedObject var state: RecorderControlState
    @State private var micDenied = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var frozenMeterHistory: [Float] = []  // Freeze history when recording stops

    var onFinishRecording: ((URL) -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Timer display and waveform section
                    VStack(spacing: 0) {
                        Text(TimeFormatter.formatTimestamp(elapsedTime))
                            .font(.dmSansMedium(size: 14))
                            .foregroundColor(.warmGray700)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.baseWhite)
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
                            .frame(width: geometry.size.width.isFinite ? geometry.size.width / 2 : 0)
                            .padding(.top, 80)
                            .offset(x: geometry.size.width.isFinite ? -geometry.size.width / 4 : 0)
                            
                            // Vertical line on top - centered and fully opaque
                            Rectangle()
                                .fill(Color.baseWhite)
                                .frame(width: 3, height: 240)
                        }
                    }
                    
                    Spacer()
                    
                    // Bottom buttons - 64px from bottom including safe area
                    HStack(spacing: 0) {
                    // Retry button - only visible when recording is stopped (not during recording)
                    // Left spacer to balance the layout
                    HStack {
                        if !rec.isRecording && rec.fileURL != nil {
                            Spacer()
                            Button {
                                playTapHaptic()
                                resetRecording()
                            } label: {
                                retryButton
                                    .foregroundColor(.warning)
                            }
                            .padding(.trailing, 8)
                        } else {
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 24)

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
                                .fill(Color.baseWhite)
                                .frame(width: 72, height: 72)

                            centerButtonContent
                        }
                    }

                    // Right spacer to balance the layout
                    Spacer()
                        .frame(maxWidth: .infinity)
                        .padding(.leading, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 64)
                }
            }
        }
        .task {
            rec.requestPermission { ok in
                micDenied = (ok == false)
            }
        }
        .onChange(of: rec.isRecording) { _, isRecording in
            if isRecording {
                startTimer()
                frozenMeterHistory = []  // Clear frozen history when starting new recording
                #if canImport(UIKit)
                // Prevent display from turning off during recording
                UIApplication.shared.isIdleTimerDisabled = true
                #endif
            } else {
                stopTimer()
                #if canImport(UIKit)
                // Re-enable display auto-lock when not recording
                UIApplication.shared.isIdleTimerDisabled = false
                #endif
            }
        }
        .onChange(of: rec.fileURL) { _, newURL in
            // Update shared state so RecorderView can auto-save if needed
            state.currentFileURL = newURL
        }
        .onChange(of: rec.wasInterrupted) { _, interrupted in
            if interrupted {
                // Recording was interrupted - trigger immediate save notification
                state.shouldAutoSave = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            handleAppWillBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            handleAppDidEnterBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            handleAppWillEnterForeground()
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
        .onDisappear {
            #if canImport(UIKit)
            // Ensure idle timer is always restored when view disappears
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
    }

    // MARK: - View Components
    private var retryButton: some View {
        HStack(spacing: 8) {
            Image("arrow-clockwise")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
            Text("Retry")
                .font(.system(size: 17, weight: .medium))
        }
    }

    @ViewBuilder
    private var centerButtonContent: some View {
        if rec.isRecording {
            // Recording: red square
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.pink)
                .frame(width: 24, height: 24)
        } else if rec.fileURL == nil {
            // Not started: red circle
            Circle()
                .fill(Color.pink)
                .frame(width: 48, height: 48)
        } else {
            // Recorded: checkmark
            Image("check-bold")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .foregroundColor(.baseBlack)
        }
    }

    // MARK: - Actions
    private func startRecording() {
        // Recording is completely independent of model loading
        // Model only needs to be ready when transcription starts (after recording finishes)
        player.stop()
        elapsedTime = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            rec.start()
        }
    }
    
    private func stopRecording() {
        frozenMeterHistory = rec.meterHistory
        rec.stop()
    }
    
    private func resetRecording() {
        rec.reset()
        elapsedTime = 0
        frozenMeterHistory = []  // Clear frozen history on reset
    }
    
    private func finishRecording() {
        if rec.isRecording {
            rec.stop()
        }
        if let fileURL = rec.fileURL {
            // Verify the file actually exists before proceeding
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                Logger.error("RecorderControl", "Recording file does not exist at: \(fileURL.path)")
                // Don't proceed if file doesn't exist
                return
            }
            // Model will be loaded when transcription starts - no need to block here
            onFinishRecording?(fileURL)
        } else {
            Logger.error("RecorderControl", "No file URL available after recording")
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            elapsedTime += 0.01

            // Check if recording has reached the maximum duration (5 hours)
            if elapsedTime >= AppConstants.Recording.maxRecordingDuration {
                Logger.info("RecorderControl", "Recording reached maximum duration of 5 hours - automatically stopping")
                stopRecording()
            }
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

    // MARK: - Lifecycle Handlers
    private func handleAppWillBackground() {
        // App is about to go to background - stop recording to save audio
        if rec.isRecording {
            Logger.warning("RecorderControl", "App backgrounding - stopping recording")
            stopRecording()
            state.shouldAutoSave = true
        }
    }

    private func handleAppDidEnterBackground() {
        // Backup: ensure recording is stopped when entering background
        if rec.isRecording {
            Logger.warning("RecorderControl", "App entered background - stopping recording")
            stopRecording()
            state.shouldAutoSave = true
        }
    }

    private func handleAppWillEnterForeground() {
        // App returning from background - finalize any interrupted recording
        if let fileURL = rec.fileURL, !rec.isRecording {
            Logger.info("RecorderControl", "App returning from background with stopped recording")

            // Verify file exists and is properly saved
            if FileManager.default.fileExists(atPath: fileURL.path) {
                Logger.success("RecorderControl", "Recording file confirmed at: \(fileURL.lastPathComponent)")

                // Ensure UI shows check icon by keeping fileURL and stopped state
                // The check icon appears when: !rec.isRecording && rec.fileURL != nil

                // Trigger auto-save to ensure recording is in database
                state.shouldAutoSave = true
            } else {
                Logger.error("RecorderControl", "Recording file missing after background")
            }
        }
    }
}
