import SwiftUI

struct TypingCursorView: View {
    @State private var blink = false
    
    var body: some View {
        Text("▋")
            .font(.custom("DMSans-Regular", size: 16))
            .foregroundColor(.baseBlack)
            .opacity(blink ? 0.3 : 1.0)
            .animation(
                Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: blink
            )
            .onAppear {
                blink = true
            }
    }
}

