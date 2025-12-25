import SwiftUI

/// Reusable component for AI response action buttons
/// Displays Copy, Regenerate, and Export buttons with consistent styling
struct AIResponseButtons: View {
    let onCopy: () -> Void
    let onRegenerate: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Copy button
            Button(action: onCopy) {
                Image("copy")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.blueGray500)
            }
            
            // Regenerate button
            Button(action: onRegenerate) {
                Image("arrow-clockwise")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.blueGray500)
            }
            
            // Export button
            Button(action: onExport) {
                Image("export")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.blueGray500)
            }
        }
    }
}

