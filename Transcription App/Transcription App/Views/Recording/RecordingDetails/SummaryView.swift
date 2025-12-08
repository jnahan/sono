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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isGeneratingSummary {
                    // Show streaming text if available, otherwise show loading
                    if !viewModel.streamingSummary.isEmpty {
                        streamingSummaryView
                    } else {
                        loadingView
                    }
                } else if let error = viewModel.summaryError {
                    errorView(error: error)
                } else if let summary = recording.summary, !summary.isEmpty {
                    summaryContentView(summary: summary)
                } else {
                    emptyStateView
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppConstants.UI.Spacing.large)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Subviews
    
    private var streamingSummaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.streamingSummary)
                .font(.custom("Inter-Regular", size: 16))
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
                .font(.custom("Inter-Regular", size: 16))
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
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(.warmGray500)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    await viewModel.generateSummary(modelContext: modelContext)
                }
            }) {
                Text("Try Again")
                    .font(.interSemiBold(size: 16))
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
                .font(.custom("Inter-Regular", size: 16))
                .foregroundColor(.baseBlack)
            
            Button(action: {
                Task {
                    await viewModel.generateSummary(modelContext: modelContext)
                }
            }) {
                Text("Regenerate Summary")
                    .font(.interSemiBold(size: 14))
                    .foregroundColor(Color.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentLight)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 32))
                    .foregroundColor(.warmGray400)
                Text("No summary available")
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(.warmGray500)
            }
            
            Button(action: {
                Task {
                    await viewModel.generateSummary(modelContext: modelContext)
                }
            }) {
                Text("Generate Summary")
                    .font(.interSemiBold(size: 16))
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
}

// MARK: - View Model

@MainActor
class SummaryViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isGeneratingSummary = false
    @Published var summaryError: String?
    @Published var streamingSummary: String = ""
    
    // MARK: - Private Properties
    
    private let recording: Recording
    
    // MARK: - Initialization
    
    init(recording: Recording) {
        self.recording = recording
    }
    
    // MARK: - Public Methods
    
    /// Generates a summary for the recording
    func generateSummary(modelContext: ModelContext) async {
        guard !recording.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            summaryError = "Cannot generate summary: transcription is empty."
            return
        }
        
        isGeneratingSummary = true
        summaryError = nil
        
        do {
            // Truncate long transcriptions to fit context window
            let transcriptionText = TranscriptionTruncator.truncate(recording.fullText)
            
            let systemPrompt = "You are a summarization assistant. Write summaries directly without any preamble."
            
            let prompt = """
            Summarize the following transcription in 2-3 concise sentences:

            \(transcriptionText)
            """
            
            // Reset streaming text
            streamingSummary = ""
            
            // Stream the response
            let summary = try await LLMService.shared.getStreamingCompletion(
                from: prompt,
                systemPrompt: systemPrompt
            ) { chunk in
                // Update streaming summary on main thread
                Task { @MainActor in
                    self.streamingSummary += chunk
                }
            }
            
            // Validate response
            let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !trimmedSummary.isEmpty, trimmedSummary.count >= 10 else {
                summaryError = "Model returned invalid response. Please try again."
                isGeneratingSummary = false
                return
            }
            
            // Limit summary length
            let finalSummary = trimmedSummary.count > 500
                ? String(trimmedSummary.prefix(500)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
                : trimmedSummary
            
            recording.summary = finalSummary
            
            // Clear streaming text
            streamingSummary = ""
            
            // Save asynchronously to avoid blocking main thread
            await MainActor.run {
                do {
                    try modelContext.save()
                } catch {
                    summaryError = "Failed to save summary: \(error.localizedDescription)"
                }
            }
            
        } catch {
            summaryError = "Failed to generate summary: \(error.localizedDescription)"
            streamingSummary = ""
        }
        
        isGeneratingSummary = false
    }
}
