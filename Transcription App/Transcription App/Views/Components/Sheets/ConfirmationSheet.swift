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
            // Title
            Text(title)
                .font(.dmSansSemiBold(size: 24))
                .foregroundColor(.black)
                .padding(.bottom, 8)
            
            // Message
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.blueGray600)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            
            // Buttons
            VStack(spacing: 8) {
                Button {
                    onConfirm()
                    isPresented = false
                } label: {
                    Text(confirmButtonText)
                }
                .buttonStyle(WarningButtonStyle())
                
                Button {
                    isPresented = false
                } label: {
                    Text(cancelButtonText)
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
        .padding(.top, 24)
        .background(Color.white)
        .presentationDetents([.height(calculateHeight())])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.white)
        .presentationCornerRadius(16)
        .interactiveDismissDisabled(false)
    }
    
    private func calculateHeight() -> CGFloat {
        // Top padding: 24px spacing from drag handle
        let topPadding: CGFloat = 24

        // Title: ~30 (font size 24 with line height) + 8 bottom padding
        let titleHeight: CGFloat = 30 + 8

        // Message: estimate based on text length and width
        let screenWidth: CGFloat = UIScreen.main.bounds.width
        let availableWidth = max(1, screenWidth - 48) // 24pt horizontal padding on each side
        let estimatedLineHeight: CGFloat = 22 // 16pt font with line spacing
        let charactersPerLine = max(1, Int(availableWidth / 9)) // rough estimate
        let lineCount = max(1, (message.count / charactersPerLine) + (message.count % charactersPerLine > 0 ? 1 : 0))
        let messageHeight = CGFloat(lineCount) * estimatedLineHeight + 32 // + 32 bottom padding

        // Buttons: 2 buttons with spacing
        // Each button has ~56px height (including padding)
        // Spacing between buttons: 8px
        let buttonsHeight: CGFloat = 56 + 8 + 56

        // Bottom padding: 24px
        let bottomPadding: CGFloat = 24

        let totalHeight = topPadding + titleHeight + messageHeight + buttonsHeight + bottomPadding

        // Ensure result is finite and reasonable
        return totalHeight.isFinite ? totalHeight : 300
    }
}





