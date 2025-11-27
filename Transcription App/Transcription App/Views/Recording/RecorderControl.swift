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
    @State private var micDenied = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var onFinishRecording: ((URL) -> Void)?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.white,
                    Color.accentLight.opacity(0.3),
                    Color.accentLight.opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Timer display
                VStack(spacing: 24) {
                    Text(formattedTime)
                        .font(.system(size: 48, weight: .regular))
                        .foregroundColor(.baseBlack)
                        .monospacedDigit()
                    
                    // Vertical line
                    Rectangle()
                        .fill(Color.warmGray300)
                        .frame(width: 2, height: 200)
                }
                
                // Waveform visualizer
                RecorderVisualizer(values: rec.meterHistory, barCount: 40)
                    .frame(height: 80)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Bottom buttons
                HStack(spacing: 80) {
                    // Retry button
                    Button {
                        playTapHaptic()
                        resetRecording()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18))
                            Text("Retry")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.accent)
                    }
                    .disabled(!rec.isRecording && rec.fileURL == nil)
                    .opacity((!rec.isRecording && rec.fileURL == nil) ? 0.3 : 1)
                    
                    // Record/Stop button
                    Button {
                        playTapHaptic()
                        if rec.isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
                            
                            if rec.isRecording {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accent)
                                    .frame(width: 32, height: 32)
                            } else {
                                Circle()
                                    .fill(Color.accent)
                                    .frame(width: 64, height: 64)
                            }
                        }
                    }
                    
                    // Done button
                    Button {
                        playTapHaptic()
                        finishRecording()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18))
                            Text("Done")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.baseBlack)
                    }
                    .disabled(rec.fileURL == nil)
                    .opacity(rec.fileURL == nil ? 0.3 : 1)
                }
                .padding(.bottom, 60)
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
    
    // MARK: - Computed Properties
    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let milliseconds = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d:%02d", minutes, seconds, milliseconds)
    }
    
    // MARK: - Actions
    private func startRecording() {
        player.stop()
        elapsedTime = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            rec.start()
        }
    }
    
    private func stopRecording() {
        rec.stop()
    }
    
    private func resetRecording() {
        if rec.isRecording {
            rec.stop()
        }
        elapsedTime = 0
        // Don't try to set fileURL directly, just start a new recording
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            startRecording()
        }
    }
    
    private func finishRecording() {
        if rec.isRecording {
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
