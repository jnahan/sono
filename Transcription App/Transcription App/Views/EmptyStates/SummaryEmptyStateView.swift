import SwiftUI

struct SummaryEmptyStateView: View {
    let onSummarize: () -> Void

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 24) {
                Text("Summarize your\nrecordings")
                    .font(.dmSansSemiBold(size: 24))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.baseBlack)

                Button(action: onSummarize) {
                    HStack(spacing: 8) {
                        Image("sparkle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color.accent)

                        Text("Summarize")
                            .font(.dmSansMedium(size: 16))
                            .foregroundColor(Color.warmGray600)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.baseWhite)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.warmGray200, lineWidth: 1)
                    )
                }
            }
            .padding(.vertical, 120)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

