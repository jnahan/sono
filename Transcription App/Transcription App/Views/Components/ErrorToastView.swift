import SwiftUI

struct ErrorToastView: View {
    let message: String
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.baseBlack)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(16)
        .background(Color.warning.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, AppConstants.UI.Spacing.large)
        .padding(.top, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
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


