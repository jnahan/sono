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
    @ObservedObject var viewModel: AskSonoViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.messages.isEmpty {
                        AskSonoEmptyStateView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(viewModel.messages) { message in
                            messageBubble(message: message)
                                .id(message.id)
                        }
                    }

                    Color.clear.frame(height: 1).id("bottom-anchor")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: viewModel.isProcessing) { _, isProcessing in
                if !isProcessing { scrollToBottom(proxy) }
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                if viewModel.streamingMessageId != nil {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("bottom-anchor", anchor: .bottom)
                    }
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation { proxy.scrollTo("bottom-anchor", anchor: .bottom) }
        }
    }

    @ViewBuilder
    private func messageBubble(message: ChatMessage) -> some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 60)
                Text(message.text)
                    .font(.dmSansRegular(size: 16))
                    .foregroundColor(.baseBlack)
                    .lineSpacing(4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.accentLight)
                    .cornerRadius(12)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            let isStreaming = viewModel.streamingMessageId != nil && message.id == viewModel.messages.last?.id
            let hasStreamingText = isStreaming && !viewModel.streamingText.isEmpty
            let showThinking = isStreaming && viewModel.streamingText.isEmpty

            VStack(alignment: .leading, spacing: 8) {
                if showThinking {
                    VStack(alignment: .leading, spacing: 8) {
                        PulsatingDot()
                        Text("Thinking...")
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
                        if hasStreamingText && !viewModel.chunkProgress.isEmpty {
                            HStack(spacing: 8) {
                                PulsatingDot()
                                Text(viewModel.chunkProgress)
                                    .font(.dmSansMedium(size: 14))
                                    .foregroundColor(.accent)
                            }
                        }

                        let displayText = hasStreamingText ? viewModel.streamingText : message.text
                        Text(displayText)
                            .font(.dmSansRegular(size: 16))
                            .foregroundColor(.baseBlack)
                            .lineSpacing(4)
                    }
                }

                if !isStreaming {
                    AIResponseButtons(
                        onCopy: { UIPasteboard.general.string = message.text },
                        onRegenerate: { viewModel.resendLastMessage() },
                        onExport: { ShareHelper.shareText(message.text) }
                    )
                    .padding(.leading, 4)
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsating = true
                }
            }
    }
}

