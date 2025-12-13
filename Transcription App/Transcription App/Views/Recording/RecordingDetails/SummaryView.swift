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
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppConstants.UI.Spacing.large)
                .padding(.bottom, 24)
            }
        } else if let error = viewModel.summaryError {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    errorView(error: error)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppConstants.UI.Spacing.large)
                .padding(.bottom, 24)
            }
        } else if let summary = recording.summary, !summary.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryContentView(summary: summary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppConstants.UI.Spacing.large)
                .padding(.bottom, 24)
            }
        } else {
            SummaryEmptyStateView {
                Task {
                    await viewModel.generateSummary(modelContext: modelContext)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundColor(.warmGray400)
                Text(error)
                    .font(.dmSansRegular(size: 16))
                    .foregroundColor(.warmGray500)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    await viewModel.generateSummary(modelContext: modelContext)
                }
            }) {
                Text("Try Again")
                    .font(.dmSansSemiBold(size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accent)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, AppConstants.UI.Spacing.large)
    }
    
    private func summaryContentView(summary: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(summary)
                .font(.dmSansRegular(size: 16))
                .foregroundColor(.baseBlack)
            
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
            .scaleEffect(isPulsating ? 1.2 : 1.0)
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

// MARK: - Summary Empty State

struct SummaryEmptyStateView: View {
    let onSummarize: () -> Void

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 24) {
                Text("Summarize your\nrecordings")
                    .font(.dmSansSemiBold(size: 24))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.baseBlack)

                Button(action: onSummarize) {
                    HStack(spacing: 8) {
                        Image("sparkle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color.accent)

                        Text("Summarize")
                            .font(.dmSansMedium(size: 16))
                            .foregroundColor(Color.warmGray600)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.baseWhite)
                    .clipShape(Capsule())
                }
            }
            .padding(.bottom, 120)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
