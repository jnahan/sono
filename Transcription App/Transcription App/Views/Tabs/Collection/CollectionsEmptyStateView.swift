import SwiftUI

struct CollectionsEmptyStateView: View {
    @Binding var showCreateCollection: Bool

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 24) {
                Text("Organize your\nrecordings")
                    .font(.dmSansSemiBold(size: 24))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.baseBlack)

                Button {
                    showCreateCollection = true
                } label: {
                    HStack(spacing: 8) {
                        Image("folder-plus")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color.accent)

                        Text("New collection")
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
            .padding(.bottom, 80)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

