import SwiftUI

struct TranscriptView: View {
    let recording: Recording
    let audioPlayback: AudioPlaybackService
    var onRetryTranscription: (() -> Void)? = nil

    var bottomContentPadding: CGFloat = 24

    private var showTimestamps: Bool {
        SettingsManager.shared.showTimestamps
    }

    var body: some View {
        // IMPORTANT: no ScrollView here. Parent scrolls everything.
        VStack(alignment: .leading, spacing: 12) {
            if recording.status == .failed {
                failedStateView
            } else if showTimestamps && !recording.segments.isEmpty {
                ForEach(recording.segments.sorted(by: { $0.start < $1.start })) { segment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(TimeFormatter.formatTimestamp(segment.start))
                            .font(.dmSansMedium(size: 14))
                            .foregroundColor(.blueGray400)
                            .monospacedDigit()

                        Text(segment.text)
                            .font(.dmSansRegular(size: 16))
                            .foregroundColor(.black)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = recording.resolvedURL {
                            if audioPlayback.isPlaying {
                                audioPlayback.seek(to: segment.start)
                            } else {
                                audioPlayback.preload(url: url)
                                audioPlayback.seek(to: segment.start)
                                audioPlayback.play()
                            }
                        }
                    }
                }
            } else {
                Text(recording.fullText)
                    .font(.dmSansRegular(size: 16))
                    .foregroundColor(.black)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, bottomContentPadding)
    }

    // MARK: - Failed State

    private var failedStateView: some View {
        VStack {
            Spacer()

            VStack(spacing: 24) {
                Text("Transcription failed")
                    .font(.dmSansSemiBold(size: 24))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)

                Button(action: {
                    HapticFeedback.light()
                    onRetryTranscription?()
                }) {
                    HStack(spacing: 8) {
                        Image("arrow-clockwise")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color.warning)

                        Text("Re-transcribe")
                            .font(.dmSansMedium(size: 16))
                            .foregroundColor(Color.blueGray600)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.blueGray200, lineWidth: 1)
                    )
                }
            }
            .padding(.vertical, 120)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
