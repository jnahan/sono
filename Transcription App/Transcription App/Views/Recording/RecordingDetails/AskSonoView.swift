//
//  AskSonoView.swift
//

import SwiftUI
import SwiftData
import UIKit

struct AskSonoView: View {
    let recording: Recording
    @ObservedObject var viewModel: AskSonoViewModel

    static let bottomAnchorId = "ASK_SONO_BOTTOM"

    /// IMPORTANT: no ScrollView here. Parent scrolls everything.
    var body: some View {
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

            // bottom anchor for parent ScrollViewReader
            Color.clear
                .frame(height: 1)
                .id(Self.bottomAnchorId)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
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
                    .fixedSize(horizontal: false, vertical: true)
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
                            .fixedSize(horizontal: false, vertical: true)
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

private struct AskSonoPulsatingDot: View {
    @State private var isPulsating = false

    var body: some View {
        Circle()
            .fill(Color.accent)
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsating ? 0.8 : 1.0)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                ) {
                    isPulsating = true
                }
            }
    }
}
