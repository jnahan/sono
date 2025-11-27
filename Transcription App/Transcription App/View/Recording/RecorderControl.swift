import SwiftUI
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit // For haptic feedback and opening Settings
#endif

// MARK: - RecorderControl
// A clean recording interface with just the recorder controls and waveform visualization
struct RecorderControl: View {
    // State object to manage recording and audio levels.
    @StateObject private var rec = MiniRecorder()
    
    // State object to manage audio playback.
    @StateObject private var player = MiniPlayer()
    
    // Tracks whether microphone permission is denied to show an alert.
    @State private var micDenied = false
    
    var onFinishRecording: ((URL) -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            
            // MARK: Title
            Text("Voice Recorder")
                .font(.title3).bold()
            
            // MARK: Waveform Visualizer - shows recent microphone level history bars.
            RecorderVisualizer(values: rec.meterHistory, barCount: 24)
                .frame(height: 54)
                .padding(.horizontal)
            
            // MARK: Simple live level bar - ProgressView version for less code.
            ProgressView(value: rec.meterLevel)
                .progressViewStyle(.linear)
                .tint(.blue.opacity(0.8))
                .frame(height: 8)
                .padding(.horizontal)
                .animation(.linear(duration: 0.05), value: rec.meterLevel)
            
            // MARK: Buttons - Record/Stop and Play current recording.
            HStack(spacing: 12) {
                
                // Record button toggles recording state.
                // In RecorderControl.swift - update the Record button action:

                Button(rec.isRecording ? "Stop" : "Record") {
                    playTapHaptic()
                    if rec.isRecording {
                        rec.stop()
                        if let fileURL = rec.fileURL {
                            onFinishRecording?(fileURL)
                        }
                    } else {
                        // ✅ MAKE SURE TO STOP PLAYER FIRST
                        player.stop()
                        
                        // ✅ ADD A SMALL DELAY TO LET AUDIO SESSION SETTLE
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            rec.start()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                
                // Play button plays the current recording if available.
                Button("Play") {
                    playTapHaptic()
                    player.play(rec.fileURL)
                }
                .buttonStyle(.bordered)
                .disabled(rec.isRecording || rec.fileURL == nil) // Disable while recording or if no file.
            }
            
            // MARK: Current recording file info
            if let url = rec.fileURL {
                Text("File: \(url.lastPathComponent)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle) // Show start and end of filename for readability.
            }
            
            Spacer() // Push content to top.
        }
        .padding()
        .task {
            // Request permission to record when view appears.
            rec.requestPermission { ok in
                // Show an alert if permission is denied.
                micDenied = (ok == false)
            }
        }
        .onChange(of: rec.isRecording) { _, isRecording in
            // Stop player when recording starts
            if isRecording {
                player.stop()
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
    
    // MARK: - Helpers
    private func playTapHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}
