//
//  AskSonoView.swift
//

import SwiftUI
import SwiftData

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
                    .foregroundColor(.black)
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
            let isLoadingModel = viewModel.state == .loadingModel && isStreaming
            let showThinking = isStreaming && viewModel.streamingText.isEmpty && !isLoadingModel

            VStack(alignment: .leading, spacing: 8) {
                if isLoadingModel {
                    VStack(alignment: .leading, spacing: 8) {
                        PulsatingDot()

                        Text("Loading AI model...")
                            .font(.dmSansRegular(size: 16))
                            .foregroundColor(.black)
                    }
                } else if showThinking {
                    VStack(alignment: .leading, spacing: 8) {
                        PulsatingDot()

                        Text("Thinking...")
                            .font(.dmSansRegular(size: 16))
                            .foregroundColor(.black)

                        if !viewModel.chunkProgress.isEmpty {
                            Text(viewModel.chunkProgress)
                                .font(.dmSansRegular(size: 14))
                                .foregroundColor(.blueGray500)
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
                            .foregroundColor(.black)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !isStreaming {
                    AIResponseButtons(
                        onCopy: {
                            HapticFeedback.success()
                            UIPasteboard.general.string = message.text
                        },
                        onRegenerate: { viewModel.resendLastMessage() },
                        onExport: {
                            HapticFeedback.light()
                            ShareHelper.shareText(message.text)
                        }
                    )
                    .padding(.leading, 4)
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

