//
//  AskSonoInputBar.swift
//

import SwiftUI

struct AskSonoInputBar: View {
    @ObservedObject var viewModel: AskSonoViewModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    if viewModel.userPrompt.isEmpty {
                        Text("Ask me anything...")
                            .font(.dmSansRegular(size: 16))
                            .foregroundColor(.blueGray500)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $viewModel.userPrompt, axis: .vertical)
                        .font(.dmSansRegular(size: 16))
                        .foregroundColor(.black)
                        .tint(.black)
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        // Keep your rebuild behavior
                        .id("askSonoInput-\(viewModel.inputFieldId)")
                        // ✅ Send on keyboard "return"/submit
                        .submitLabel(.send)
                        .onSubmit {
                            guard !viewModel.isProcessing else { return }
                            Task { await viewModel.sendPrompt() }
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())

                Spacer()

                Button(action: {
                    // ✅ Don’t clear locally — VM clears userPrompt
                    isInputFocused = false
                    guard !viewModel.isProcessing else { return }
                    Task { await viewModel.sendPrompt() }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.accent)
                            .frame(width: 32, height: 32)

                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image("I")
                                .resizable()
                                .renderingMode(.template)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing)
            }
            .padding(.leading, 16)
            .padding(.top, 10)
            .padding(.trailing, 10)
            .padding(.bottom, 10)
            .background(Color.blueGray50)
            .cornerRadius(32)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }
}
