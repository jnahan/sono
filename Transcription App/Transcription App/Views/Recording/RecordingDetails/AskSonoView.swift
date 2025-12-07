import SwiftUI
import SwiftData

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date = Date()
}

struct AskSonoView: View {
    let recording: Recording
    @StateObject private var viewModel: AskSonoViewModel
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool
    
    init(recording: Recording) {
        self.recording = recording
        _viewModel = StateObject(wrappedValue: AskSonoViewModel(recording: recording))
    }
    
    var body: some View {
        ZStack {
            Color.warmGray50
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            if viewModel.messages.isEmpty {
                                // Empty state
                                VStack(spacing: 12) {
                                    Text("How can I help you")
                                        .font(.libreMedium(size: 24))
                                        .foregroundColor(.baseBlack)
                                        .padding(.top, 40)
                                }
                            } else {
                                // Chat messages
                                ForEach(viewModel.messages) { message in
                                    messageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                // Loading indicator
                                if viewModel.isProcessing {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Thinking...")
                                            .font(.custom("Inter-Regular", size: 14))
                                            .foregroundColor(.warmGray500)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, AppConstants.UI.Spacing.large)
                                    .padding(.top, 8)
                                }
                            }
                        }
                        .padding(.horizontal, AppConstants.UI.Spacing.large)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isProcessing) { _, isProcessing in
                        if !isProcessing, let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input Area
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        // Text Input
                        HStack(spacing: 8) {
                            TextField("Ask me anything...", text: $viewModel.userPrompt, axis: .vertical)
                                .font(.custom("Inter-Regular", size: 16))
                                .foregroundColor(.baseBlack)
                                .focused($isInputFocused)
                                .lineLimit(1...5)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(24)
                            
                            // Send Button
                            Button(action: {
                                Task {
                                    await viewModel.sendPrompt()
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(viewModel.userPrompt.isEmpty || viewModel.isProcessing ? Color.warmGray400 : Color.accent)
                                        .frame(width: 44, height: 44)
                                    
                                    if viewModel.isProcessing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .disabled(viewModel.userPrompt.isEmpty || viewModel.isProcessing)
                        }
                    }
                    .padding(.horizontal, AppConstants.UI.Spacing.large)
                    .padding(.vertical, 12)
                    .background(Color.warmGray50)
                }
            }
        }
    }
    
    // MARK: - Message Bubble
    
    @ViewBuilder
    private func messageBubble(message: ChatMessage) -> some View {
        if message.isUser {
            // User message - right aligned, pink bubble
            HStack {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .font(.custom("Inter-Regular", size: 16))
                        .foregroundColor(.baseBlack)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.accentLight)
                        .cornerRadius(20)
                }
            }
        } else {
            // AI message - left aligned, white bubble with actions
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(message.text)
                            .font(.custom("Inter-Regular", size: 16))
                            .foregroundColor(.baseBlack)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(20)
                    }
                    
                    Spacer(minLength: 60)
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    actionButton(icon: "doc.on.doc", action: {
                        UIPasteboard.general.string = message.text
                    })
                    
                    actionButton(icon: "arrow.clockwise", action: {
                        viewModel.resendLastMessage()
                    })
                    
                    actionButton(icon: "square.and.arrow.up", action: {
                        ShareHelper.shareText(message.text)
                    })
                }
                .padding(.leading, 4)
            }
        }
    }
    
    private func actionButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.warmGray500)
                .frame(width: 24, height: 24)
        }
    }
}

// MARK: - View Model

@MainActor
class AskSonoViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var userPrompt: String = ""
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing: Bool = false
    @Published var error: String?
    
    // MARK: - Private Properties
    
    private let recording: Recording
    
    // MARK: - Initialization
    
    init(recording: Recording) {
        self.recording = recording
    }
    
    // MARK: - Public Methods
    
    /// Sends the user's prompt to the LLM with transcription context
    func sendPrompt() async {
        let promptText = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptText.isEmpty else {
            return
        }
        
        guard !recording.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Cannot answer questions: transcription is empty."
            return
        }
        
        // Add user message to chat
        let userMessage = ChatMessage(text: promptText, isUser: true)
        messages.append(userMessage)
        
        // Clear input
        userPrompt = ""
        
        isProcessing = true
        error = nil
        
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
            
            let systemPrompt = "You are a helpful assistant that answers questions about transcriptions. Answer questions directly and concisely based on the provided transcription."
            
            let prompt = """
            Transcription:
            \(transcriptionText)
            
            Question: \(promptText)
            """
            
            let llmResponse = try await LLMService.shared.getCompletion(
                from: prompt,
                systemPrompt: systemPrompt
            )
            
            // Validate response
            let trimmedResponse = llmResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !trimmedResponse.isEmpty, trimmedResponse.count >= 10 else {
                error = "Model returned invalid response. Please try again."
                isProcessing = false
                return
            }
            
            // Add AI response to chat
            let aiMessage = ChatMessage(text: trimmedResponse, isUser: false)
            messages.append(aiMessage)
            
        } catch {
            self.error = "Failed to get response: \(error.localizedDescription)"
            // Add error message to chat
            let errorMessage = ChatMessage(text: "Sorry, I encountered an error. Please try again.", isUser: false)
            messages.append(errorMessage)
        }
        
        isProcessing = false
    }
    
    /// Resends the last user message
    func resendLastMessage() {
        guard let lastUserMessage = messages.last(where: { $0.isUser }) else {
            return
        }
        
        // Remove the last AI response if it exists
        if let lastIndex = messages.indices.last, !messages[lastIndex].isUser {
            messages.removeLast()
        }
        
        userPrompt = lastUserMessage.text
        Task {
            await sendPrompt()
        }
    }
}
