import SwiftUI

struct ConfirmationSheet: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmButtonText: String
    let cancelButtonText: String
    let onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.warmGray300)
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Title
            Text(title)
                .font(.custom("LibreBaskerville-Regular", size: 24))
                .foregroundColor(.baseBlack)
                .padding(.bottom, 16)
            
            // Message
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.warmGray600)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            
            // Buttons
            VStack(spacing: 12) {
                Button {
                    onConfirm()
                    isPresented = false
                } label: {
                    Text(confirmButtonText)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.red)
                        .cornerRadius(16)
                }
                .padding(.horizontal, AppConstants.UI.Spacing.large)
                
                Button {
                    isPresented = false
                } label: {
                    Text(cancelButtonText)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.baseBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .padding(.horizontal, AppConstants.UI.Spacing.large)
            }
            .padding(.bottom, 20)
        }
        .background(Color.warmGray100)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.warmGray100)
        .presentationCornerRadius(24)
    }
}
