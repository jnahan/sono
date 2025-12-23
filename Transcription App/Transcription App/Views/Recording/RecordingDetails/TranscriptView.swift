import SwiftUI

struct TranscriptView: View {
    let recording: Recording
    let audioPlayback: AudioPlaybackService
    @ObservedObject var viewModel: RecordingDetailsViewModel

    var bottomContentPadding: CGFloat = 24

    private var showTimestamps: Bool {
        SettingsManager.shared.showTimestamps
    }

    var body: some View {
        // IMPORTANT: no ScrollView here. Parent scrolls everything.
        VStack(alignment: .leading, spacing: 12) {
            if showTimestamps && !recording.segments.isEmpty {
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
                    .foregroundColor(.baseBlack)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, bottomContentPadding)
    }
}
