import SwiftUI
import SwiftData
import UIKit

struct ChatMessage: Identifiable, Equatable {
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
    let activationToken: UUID

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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scrollToBottomIfNeeded(proxy: proxy, animated: false)
            }
            .onChange(of: activationToken) { _, _ in
                // tab became active -> jump to last message
                scrollToBottomIfNeeded(proxy: proxy, animated: false)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottomIfNeeded(proxy: proxy, animated: true)
            }
            .onChange(of: viewModel.isProcessing) { _, isProcessing in
                if !isProcessing {
                    scrollToBottomIfNeeded(proxy: proxy, animated: true)
                }
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                // keep following streaming output
                scrollToBottomIfNeeded(proxy: proxy, animated: false)
            }
        }
    }

    private func scrollToBottomIfNeeded(proxy: ScrollViewProxy, animated: Bool) {
        guard let last = viewModel.messages.last else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Message Bubble

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
        } else {
            let isStreaming = viewModel.streamingMessageId != nil && message.id == viewModel.messages.last?.id
            let hasStreamingText = isStreaming && !viewModel.streamingText.isEmpty
            let showThinking = isStreaming && viewModel.streamingText.isEmpty

            VStack(alignment: .leading, spacing: 8) {
                if showThinking {
                    VStack(alignment: .leading, spacing: 8) {
                        AskSonoPulsatingDot()

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
                                AskSonoPulsatingDot()
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

// MARK: - Unique dot name to avoid redeclaration conflicts

private struct AskSonoPulsatingDot: View {
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
