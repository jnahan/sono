import SwiftUI

struct CustomSwitch: View {
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }) {
            ZStack {
                // Base
                RoundedRectangle(cornerRadius: 14)
                    .fill(isOn ? Color.accent : Color.warmGray300)
                    .frame(width: 48, height: 28)
                
                // Circle
                Circle()
                    .fill(isOn ? Color.baseWhite : Color.warmGray400)
                    .frame(width: 24, height: 24)
                    .offset(x: isOn ? 10 : -10) // 2px from edges: ON = 48/2 - 24/2 - 2 = 10, OFF = -48/2 + 24/2 + 2 = -10
            }
        }
        .buttonStyle(.plain)
    }
}
