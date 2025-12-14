//
//  RecordingPlayerBar.swift
//  Transcription App
//

import SwiftUI

/// Complete player bar for recordings - includes progress, playback, and action buttons
/// All controls in one cohesive component
struct RecordingPlayerBar: View {

    // MARK: - Properties

    @ObservedObject var audioService: AudioPlaybackService
    let audioURL: URL?
    let fullText: String
    var onNotePressed: () -> Void
    var onSharePressed: () -> Void
    var onAIPressed: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar and time labels
            VStack(spacing: 12) {
                progressSlider
                timeLabels
            }
            .padding(.horizontal, AppConstants.UI.Spacing.large)

            // Action buttons with play button in center
            HStack(spacing: 0) {
                // AI Assistant button
                IconButton(icon: "sparkle", action: onAIPressed)

                Spacer()

                // Note button
                IconButton(icon: "note", action: onNotePressed)

                Spacer()

                // Play/Pause button (center)
                playPauseButton

                Spacer()

                // Copy button
                IconButton(icon: "copy") {
                    UIPasteboard.general.string = fullText
                }

                Spacer()

                // Share button
                IconButton(icon: "export", action: onSharePressed)
            }
            .padding(.horizontal, AppConstants.UI.Spacing.large)
            .padding(.bottom, 28)
        }
        .background(Color.warmGray50)
    }

    // MARK: - Subviews

    private var progressSlider: some View {
        CustomSlider(
            value: Binding(
                get: { audioService.currentTime },
                set: { audioService.seek(to: $0) }
            ),
            range: 0...max(audioService.duration, 0.1)
        ) { _ in }
    }

    private var timeLabels: some View {
        HStack {
            Text(TimeFormatter.formatTimestamp(audioService.currentTime))
                .font(.system(size: 12))
                .foregroundColor(.warmGray400)
                .monospacedDigit()

            Spacer()

            Text(TimeFormatter.formatTimestamp(audioService.duration))
                .font(.system(size: 12))
                .foregroundColor(.warmGray400)
                .monospacedDigit()
        }
    }

    private var playPauseButton: some View {
        Button {
            audioService.togglePlayback(url: audioURL)
        } label: {
            Image(audioService.isPlaying ? "pause-fill" : "play-fill")
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
                .overlay(
                    Circle()
                        .stroke(Color.warmGray200, lineWidth: 1)
                )
        )
    }
}
