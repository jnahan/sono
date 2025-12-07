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
                    loadingView
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
            let maxInputLength = 3000
            let transcriptionText: String
            
            if recording.fullText.count > maxInputLength {
                let beginningLength = Int(Double(maxInputLength) * 0.6)
                let endLength = maxInputLength - beginningLength - 50
                let beginning = String(recording.fullText.prefix(beginningLength))
                let end = String(recording.fullText.suffix(endLength))
                transcriptionText = "\(beginning)\n\n[...]\n\n\(end)"
            } else {
                transcriptionText = recording.fullText
            }
            
            let systemPrompt = "You are a summarization assistant. Write summaries directly without any preamble."
            
            let prompt = """
            Summarize the following transcription in 2-3 concise sentences:

            \(transcriptionText)
            """
            
            let summary = try await LLMService.shared.getCompletion(
                from: prompt,
                systemPrompt: systemPrompt
            )
            
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
            
            try modelContext.save()
            
        } catch {
            summaryError = "Failed to generate summary: \(error.localizedDescription)"
        }
        
        isGeneratingSummary = false
    }
}
