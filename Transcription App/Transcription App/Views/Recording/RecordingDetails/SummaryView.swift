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
            // Show streaming text if available, otherwise show loading
            if !viewModel.streamingSummary.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        streamingSummaryView
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppConstants.UI.Spacing.large)
                    .padding(.bottom, 24)
                }
            } else {
                loadingView
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
    
    private var streamingSummaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.streamingSummary)
                .font(.dmSansRegular(size: 16))
                .foregroundColor(.baseBlack)
                .transition(.opacity)
            
            // Show typing indicator
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.warmGray400)
                        .frame(width: 6, height: 6)
                        .opacity(0.3)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: viewModel.streamingSummary
                        )
                }
            }
            .padding(.top, 4)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Generating summary...")
                .font(.dmSansRegular(size: 16))
                .foregroundColor(.warmGray500)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
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
            
            Button(action: {
                Task {
                    await viewModel.generateSummary(modelContext: modelContext)
                }
            }) {
                Text("Regenerate Summary")
                    .font(.dmSansSemiBold(size: 14))
                    .foregroundColor(Color.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentLight)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
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
