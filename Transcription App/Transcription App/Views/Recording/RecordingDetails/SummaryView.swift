//
//  SummaryView.swift
//

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
            if viewModel.isGeneratingSummary {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if viewModel.streamingSummary.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                PulsatingDot()

                                Text("Summarizing...")
                                    .font(.dmSansRegular(size: 16))
                                    .foregroundColor(.baseBlack)

                                if !viewModel.chunkProgress.isEmpty {
                                    Text(viewModel.chunkProgress)
                                        .font(.dmSansRegular(size: 14))
                                        .foregroundColor(.warmGray500)
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
                                    .foregroundColor(.baseBlack)
                                    .lineSpacing(4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            } else if let summary = recording.summary, !summary.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryContentView(summary: summary)

                        if let error = viewModel.summaryError {
                            Text(error)
                                .font(.dmSansRegular(size: 14))
                                .foregroundColor(.red)
                                .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            } else if let error = viewModel.summaryError {
                VStack(alignment: .leading, spacing: 16) {
                    errorContentView(error: error)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            } else {
                SummaryEmptyStateView {
                    Task {
                        await viewModel.generateSummary(modelContext: modelContext)
                    }
                }
                // ensure empty state can expand
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Subviews

    private func errorContentView(error: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(error)
                .font(.dmSansRegular(size: 16))
                .foregroundColor(.baseBlack)

            AIResponseButtons(
                onCopy: { UIPasteboard.general.string = error },
                onRegenerate: {
                    Task { await viewModel.generateSummary(modelContext: modelContext) }
                },
                onExport: { ShareHelper.shareText(error) }
            )
        }
    }

    private func summaryContentView(summary: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(summary)
                .font(.dmSansRegular(size: 16))
                .foregroundColor(.baseBlack)
                .lineSpacing(4)

            AIResponseButtons(
                onCopy: { UIPasteboard.general.string = summary },
                onRegenerate: {
                    Task { await viewModel.generateSummary(modelContext: modelContext) }
                },
                onExport: { ShareHelper.shareText(summary) }
            )
        }
    }
}

private struct PulsatingDot: View {
    @State private var isPulsating = false

    var body: some View {
        Circle()
            .fill(Color.accent)
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsating ? 0.8 : 1.0)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                ) {
                    isPulsating = true
                }
            }
    }
}
