import SwiftUI

struct TranscriptView: View {
    let recording: Recording
    @ObservedObject var audioPlayback: AudioPlaybackService
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
                        let isActive = viewModel.isSegmentActive(
                            segment: segment,
                            currentTime: audioPlayback.currentTime,
                            isPlaying: audioPlayback.isPlaying
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(TimeFormatter.formatTimestamp(segment.start))
                                .font(.dmSansMedium(size: 14))
                                .foregroundColor(.warmGray400)
                                .monospacedDigit()

                            Text(attributedText(for: segment.text, isActive: isActive))
                                .foregroundColor(.baseBlack)
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
                        .font(.custom("DMSans-Regular", size: 16))
                        .foregroundColor(.baseBlack)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppConstants.UI.Spacing.large)
            .padding(.bottom, 180)
        }
        .onChange(of: audioPlayback.currentTime) { _, _ in
            viewModel.updateActiveSegment(
                currentTime: audioPlayback.currentTime,
                isPlaying: audioPlayback.isPlaying,
                showTimestamps: showTimestamps
            )
        }
        .onChange(of: audioPlayback.isPlaying) { _, isPlaying in
            if !isPlaying {
                viewModel.resetActiveSegment()
            }
        }
    }

    // MARK: - Helper Methods

    private func attributedText(for text: String, isActive: Bool) -> AttributedString {
        var attributedString = AttributedString(text)

        // Guard against empty strings to avoid range errors
        guard !text.isEmpty, attributedString.startIndex < attributedString.endIndex else {
            return attributedString
        }

        // Set font and color using attribute container
        var container = AttributeContainer()
        container.font = UIFont(name: "DMSans-9ptRegular", size: 16)!
        container.foregroundColor = UIColor(Color.baseBlack)

        if isActive {
            container.backgroundColor = UIColor(Color.accentLight)
        }

        // Apply attributes to entire string
        let range = attributedString.startIndex..<attributedString.endIndex
        attributedString[range].mergeAttributes(container)

        return attributedString
    }
}
