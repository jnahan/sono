import SwiftUI

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(isSelected ? .baseBlack : .warmGray400)
                
                Rectangle()
                    .fill(isSelected ? Color.baseBlack : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

