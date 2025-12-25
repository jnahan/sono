import SwiftUI

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.dmSansSemiBold(size: 14))
                    .foregroundColor(isSelected ? .accent : .blueGray400)

                Rectangle()
                    .fill(isSelected ? Color.accent : .clear)
                    .frame(height: 2)
            }
            .fixedSize()
        }
    }
}

