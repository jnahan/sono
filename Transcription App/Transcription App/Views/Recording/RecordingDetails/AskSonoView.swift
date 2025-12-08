import SwiftUI
import SwiftData

struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    
    init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
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
                    .scrollDismissesKeyboard(.interactively)
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
                    .onChange(of: viewModel.streamingText) { _, _ in
                        // Auto-scroll as text streams in
                        if let lastMessage = viewModel.messages.last, !lastMessage.isUser {
                            withAnimation(.easeOut(duration: 0.1)) {
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
                        ZStack(alignment: .leading) {
                            if viewModel.userPrompt.isEmpty {
                                Text("Ask me anything...")
                                    .font(.custom("Inter-Regular", size: 16))
                                    .foregroundColor(.warmGray400)
                                    .padding(.leading, 16)
                                    .padding(.vertical, 12)
                            }

                            TextField("", text: $viewModel.userPrompt, axis: .vertical)
                                .font(.custom("Inter-Regular", size: 16))
                                .foregroundColor(.baseBlack)
                                .tint(.baseBlack)
                                .focused($isInputFocused)
                                .lineLimit(1...5)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .background(Color.baseWhite)
                        .cornerRadius(24)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isInputFocused = true
                        }

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
                                        .progressViewStyle(CircularProgressViewStyle(tint: .baseWhite))
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.baseWhite)
                                }
                            }
                        }
                        .disabled(viewModel.userPrompt.isEmpty || viewModel.isProcessing)
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
                        HStack(alignment: .bottom, spacing: 0) {
                            Text(message.text)
                                .font(.custom("Inter-Regular", size: 16))
                                .foregroundColor(.baseBlack)
                            
                            // Show typing cursor if this is the streaming message
                            if viewModel.streamingMessageId != nil && message.id == viewModel.messages.last?.id && !message.isUser {
                                TypingCursorView()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(20)
                    }
                    
                    Spacer(minLength: 60)
                }
                
                // Action buttons (only show when not streaming)
                if viewModel.streamingMessageId == nil || message.id != viewModel.messages.last?.id {
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

// MARK: - Typing Cursor View
struct TypingCursorView: View {
    @State private var blink = false
    
    var body: some View {
        Text("▋")
            .font(.custom("Inter-Regular", size: 16))
            .foregroundColor(.baseBlack)
            .opacity(blink ? 0.3 : 1.0)
            .animation(
                Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: blink
            )
            .onAppear {
                blink = true
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
    @Published var streamingMessageId: UUID? = nil
    @Published var streamingText: String = ""
    
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
            
            // Create placeholder message for streaming
            let streamingId = UUID()
            streamingMessageId = streamingId
            streamingText = ""
            let placeholderMessage = ChatMessage(id: streamingId, text: "", isUser: false)
            messages.append(placeholderMessage)
            
            // Stream the response
            let llmResponse = try await LLMService.shared.getStreamingCompletion(
                from: prompt,
                systemPrompt: systemPrompt
            ) { chunk in
                // Update streaming text on main thread
                Task { @MainActor in
                    if self.streamingMessageId == streamingId {
                        self.streamingText += chunk
                        // Update the last message with streaming text, preserving the ID
                        if let lastIndex = self.messages.indices.last, !self.messages[lastIndex].isUser {
                            let existingMessage = self.messages[lastIndex]
                            // Create new message with updated text but same ID
                            let updatedMessage = ChatMessage(
                                id: existingMessage.id,
                                text: self.streamingText,
                                isUser: false,
                                timestamp: existingMessage.timestamp
                            )
                            self.messages[lastIndex] = updatedMessage
                        }
                    }
                }
            }
            
            // Validate response
            let trimmedResponse = llmResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !trimmedResponse.isEmpty, trimmedResponse.count >= 10 else {
                error = "Model returned invalid response. Please try again."
                isProcessing = false
                streamingMessageId = nil
                streamingText = ""
                // Remove the placeholder message
                if let lastIndex = messages.indices.last, !messages[lastIndex].isUser {
                    messages.removeLast()
                }
                return
            }
            
            // Ensure final message is set correctly with preserved ID
            if let lastIndex = messages.indices.last, !messages[lastIndex].isUser, messages[lastIndex].id == streamingId {
                let existingMessage = messages[lastIndex]
                let finalMessage = ChatMessage(
                    id: streamingId,
                    text: trimmedResponse,
                    isUser: false,
                    timestamp: existingMessage.timestamp
                )
                messages[lastIndex] = finalMessage
            }
            
            streamingMessageId = nil
            streamingText = ""
            
        } catch {
            self.error = "Failed to get response: \(error.localizedDescription)"
            // Remove streaming placeholder if it exists
            if let lastIndex = messages.indices.last, !messages[lastIndex].isUser, streamingMessageId != nil {
                messages.removeLast()
            }
            // Add error message to chat
            let errorMessage = ChatMessage(text: "Sorry, I encountered an error. Please try again.", isUser: false)
            messages.append(errorMessage)
            streamingMessageId = nil
            streamingText = ""
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

