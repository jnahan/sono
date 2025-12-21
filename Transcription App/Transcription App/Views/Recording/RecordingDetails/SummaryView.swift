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
        if viewModel.isGeneratingSummary {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.streamingSummary.isEmpty {
                        // Show "Summarizing..." with blue dot
                        VStack(alignment: .leading, spacing: 8) {
                            PulsatingDot()

                            Text("Summarizing...")
                                .font(.dmSansRegular(size: 16))
                                .foregroundColor(.baseBlack)
                        }
                    } else {
                        // Show streaming text
                        Text(viewModel.streamingSummary)
                            .font(.dmSansRegular(size: 16))
                            .foregroundColor(.baseBlack)
                            .lineSpacing(4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        } else if let summary = recording.summary, !summary.isEmpty {
            // Show summary even if there's an error (error might be informational)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryContentView(summary: summary)

                    // Show error message if present
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
        } else {
            SummaryEmptyStateView {
                Task {
                    await viewModel.generateSummary(modelContext: modelContext)
                }
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
                onCopy: {
                    UIPasteboard.general.string = error
                },
                onRegenerate: {
                    Task {
                        await viewModel.generateSummary(modelContext: modelContext)
                    }
                },
                onExport: {
                    ShareHelper.shareText(error)
                }
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
                onCopy: {
                    UIPasteboard.general.string = summary
                },
                onRegenerate: {
                    Task {
                        await viewModel.generateSummary(modelContext: modelContext)
                    }
                },
                onExport: {
                    ShareHelper.shareText(summary)
                }
            )
        }
    }
    
}

// MARK: - Pulsating Dot

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

