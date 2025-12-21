import SwiftUI

struct TranscriptView: View {
    let recording: Recording
    let audioPlayback: AudioPlaybackService
    @ObservedObject var viewModel: RecordingDetailsViewModel

    private var showTimestamps: Bool {
        SettingsManager.shared.showTimestamps
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if showTimestamps && !recording.segments.isEmpty {
                    // Show segments with timestamps when enabled
                    ForEach(recording.segments.sorted(by: { $0.start < $1.start })) { segment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(TimeFormatter.formatTimestamp(segment.start))
                                .font(.dmSansMedium(size: 14))
                                .foregroundColor(.warmGray400)
                                .monospacedDigit()

                            Text(segment.text)
                                .font(.dmSansRegular(size: 16))
                                .foregroundColor(.baseBlack)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let url = recording.resolvedURL {
                                // If already playing, just seek. Otherwise load, seek, and play.
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
                    // Show full text when timestamps are disabled or no segments
                    Text(recording.fullText)
                        .font(.dmSansRegular(size: 16))
                        .foregroundColor(.baseBlack)
                        .lineSpacing(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 180)
        }
    }
}
