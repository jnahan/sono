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
            VStack(spacing: 0) {
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            if viewModel.messages.isEmpty {
                                AskSonoEmptyStateView()
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
                                            .font(.dmSansRegular(size: 14))
                                            .foregroundColor(.warmGray500)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, AppConstants.UI.Spacing.large)
                                    .padding(.top, 8)
                                }
                            }
                        }
                        .padding(.horizontal, AppConstants.UI.Spacing.large)
                        .padding(.bottom, 16)
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
                    HStack(spacing: 0) {
                        // Text Input
                        ZStack(alignment: .leading) {
                            if viewModel.userPrompt.isEmpty {
                                Text("Ask me anything...")
                                    .font(.dmSansRegular(size: 16))
                                    .foregroundColor(.warmGray500)
                            }

                            TextField("", text: $viewModel.userPrompt, axis: .vertical)
                                .font(.dmSansRegular(size: 16))
                                .foregroundColor(.baseBlack)
                                .tint(.baseBlack)
                                .focused($isInputFocused)
                                .lineLimit(1...5)
                        }
                        
                        Spacer()
                        
                        // Send Button
                        Button(action: {
                            Task {
                                await viewModel.sendPrompt()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.accent)
                                    .frame(width: 32, height: 32)
                                
                                if viewModel.isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .baseWhite))
                                        .scaleEffect(0.7)
                                } else {
                                    Image("I")
                                        .resizable()
                                        .renderingMode(.template)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 16, height: 16)
                                        .foregroundColor(.baseWhite)
                                }
                            }
                        }
                        .disabled(viewModel.userPrompt.isEmpty || viewModel.isProcessing)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 10)
                    .padding(.trailing, 10)
                    .padding(.bottom, 10)
                    .background(Color.baseWhite)
                    .cornerRadius(32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.warmGray200, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
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
                        .font(.custom("DMSans-Regular", size: 16))
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
                                .font(.custom("DMSans-Regular", size: 16))
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
                    AIResponseButtons(
                        onCopy: {
                            UIPasteboard.general.string = message.text
                        },
                        onRegenerate: {
                            viewModel.resendLastMessage()
                        },
                        onExport: {
                            ShareHelper.shareText(message.text)
                        }
                    )
                    .padding(.leading, 4)
                    .padding(.top, 8)
                }
            }
        }
    }
    
}

// MARK: - Ask Sono Empty State

struct AskSonoEmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hi there!\nHow can I help you?")
                .font(.dmSansMedium(size: 20))
                .foregroundColor(.baseBlack)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Ideas")
                .font(.dmSansMedium(size: 16))
                .foregroundColor(.warmGray500)
                .padding(.top, 24)
            
            VStack(alignment: .leading, spacing: 16) {
                IdeaItem(
                    icon: "seal-question",
                    iconColor: .pink,
                    text: "Ask a question"
                )
                
                IdeaItem(
                    icon: "pen-nib",
                    iconColor: .teal,
                    text: "Request rewrite"
                )
                
                IdeaItem(
                    icon: "check-circle",
                    iconColor: .accent,
                    text: "Get action items"
                )
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Idea Item

private struct IdeaItem: View {
    let icon: String
    let iconColor: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(iconColor)
            
            Text(text)
                .font(.dmSansMedium(size: 16))
                .foregroundColor(.baseBlack)
        }
    }
}

