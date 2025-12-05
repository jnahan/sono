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
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            
            // Buttons
            VStack(spacing: 12) {
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
        .background(Color.warmGray100)
        .presentationDetents([.height(calculateHeight())])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.warmGray100)
        .presentationCornerRadius(24)
    }
    
    private func calculateHeight() -> CGFloat {
        // Drag handle: 5 + 12 top + 20 bottom = 37
        let dragHandleHeight: CGFloat = 37
        
        // Title: ~30 (font size 24 with padding)
        let titleHeight: CGFloat = 30 + 16 // font height + bottom padding
        
        // Message: estimate based on text length and width
        // Assuming ~40 characters per line at 16pt font with 24pt horizontal padding
        let screenWidth: CGFloat = UIScreen.main.bounds.width
        let availableWidth = max(1, screenWidth - 48) // 24pt padding on each side, ensure > 0
        let estimatedLineHeight: CGFloat = 22 // 16pt font with line spacing
        let charactersPerLine = max(1, Int(availableWidth / 9)) // rough estimate, ensure > 0
        let lineCount = max(1, (message.count / charactersPerLine) + (message.count % charactersPerLine > 0 ? 1 : 0))
        let messageHeight = CGFloat(lineCount) * estimatedLineHeight + 32 // + bottom padding
        
        // Buttons: 2 buttons with spacing
        // Each button: 16*2 (vertical padding) + ~22 (text height) + 6 (bottom padding from style) = ~60
        // Spacing between buttons: 12
        let buttonsHeight: CGFloat = 60 + 12 + 60 // first button + spacing + second button
        
        let totalHeight = dragHandleHeight + titleHeight + messageHeight + buttonsHeight
        
        // Add some safe area padding at bottom, ensure result is finite
        let finalHeight = totalHeight + 20
        return finalHeight.isFinite ? finalHeight : 300 // fallback to reasonable default
    }
}
