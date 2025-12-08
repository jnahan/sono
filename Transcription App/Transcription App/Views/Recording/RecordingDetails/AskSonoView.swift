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
