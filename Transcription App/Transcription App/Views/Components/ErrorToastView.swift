import SwiftUI

struct ErrorToastView: View {
    let message: String
    @Binding var isPresented: Bool

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding()
            .background(Color.warning)
            .cornerRadius(10)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .onAppear {
                // Auto-dismiss after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
    }
}


