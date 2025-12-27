import SwiftUI
import SwiftData

struct SummaryView: View {
    let recording: Recording
    @StateObject private var viewModel: SummaryViewModel
    @Environment(\.modelContext) private var modelContext

    init(recording: Recording) {
        self.recording = recording
        _viewModel = StateObject(wrappedValue: SummaryViewModel(recording: recording))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                if let summary = recording.summary, !summary.isEmpty {
                    summaryContentView(summary: summary)
                } else {
                    SummaryEmptyStateView(isDisabled: false) {
                        Task { await viewModel.generateSummary(modelContext: modelContext) }
                    }
                }
            case .loadingModel:
                loadingModelContent
            case .generating:
                generatingContent
            case .error(let errorMessage):
                errorContentView(error: errorMessage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Pieces

    private var loadingModelContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            PulsatingDot()

            Text("Loading AI model...")
                .font(.dmSansRegular(size: 16))
                .foregroundColor(.black)
        }
    }

    private var generatingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.streamingSummary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    PulsatingDot()

                    Text("Generating summary...")
                        .font(.dmSansRegular(size: 16))
                        .foregroundColor(.black)

                    if !viewModel.chunkProgress.isEmpty {
                        Text(viewModel.chunkProgress)
                            .font(.dmSansRegular(size: 14))
                            .foregroundColor(.blueGray500)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if !viewModel.chunkProgress.isEmpty {
                        HStack(spacing: 8) {
                            PulsatingDot()
                            Text(viewModel.chunkProgress)
                                .font(.dmSansMedium(size: 14))
                                .foregroundColor(.accent)
                        }
                    }

                    Text(viewModel.streamingSummary)
                        .font(.dmSansRegular(size: 16))
                        .foregroundColor(.black)
                        .lineSpacing(4)
                }
            }
        }
    }

    private func errorContentView(error: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(error)
                .font(.dmSansRegular(size: 16))
                .foregroundColor(.black)

            AIResponseButtons(
                onCopy: {
                    HapticFeedback.success()
                    UIPasteboard.general.string = error
                },
                onRegenerate: { Task { await viewModel.generateSummary(modelContext: modelContext) } },
                onExport: {
                    HapticFeedback.light()
                    ShareHelper.shareText(error)
                }
            )
        }
    }

    private func summaryContentView(summary: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(summary)
                .font(.dmSansRegular(size: 16))
                .foregroundColor(.black)
                .lineSpacing(4)

            AIResponseButtons(
                onCopy: {
                    HapticFeedback.success()
                    UIPasteboard.general.string = summary
                },
                onRegenerate: { Task { await viewModel.generateSummary(modelContext: modelContext) } },
                onExport: {
                    HapticFeedback.light()
                    ShareHelper.shareText(summary)
                }
            )

            if let error = viewModel.summaryError {
                Text(error)
                    .font(.dmSansRegular(size: 14))
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
    }
}

