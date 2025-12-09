import SwiftUI

/// Reusable mass action buttons component for selection mode
/// Displays Delete, Copy, and Move buttons with gradient fade and divider
struct MassActionButtons: View {
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onMove: () -> Void
    
    var horizontalPadding: CGFloat = AppConstants.UI.Spacing.large
    var bottomPadding: CGFloat = 0
    var bottomSafeAreaPadding: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Gradient fade at top of buttons
            LinearGradient(
                colors: [Color.warmGray50.opacity(0), Color.warmGray50],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)
            
            Divider()
                .background(Color.warmGray200)
            
            // Action buttons
            HStack(spacing: 12) {
                // Delete button
                Button(action: onDelete) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                        Text("Delete")
                            .font(.interMedium(size: 16))
                    }
                    .foregroundColor(.baseWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accent)
                    .cornerRadius(12)
                }
                
                // Copy button
                Button(action: onCopy) {
                    HStack(spacing: 8) {
                        Image("copy")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                        Text("Copy")
                            .font(.interMedium(size: 16))
                    }
                    .foregroundColor(.baseBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.warmGray200)
                    .cornerRadius(12)
                }
                
                // Move to collection button
                Button(action: onMove) {
                    HStack(spacing: 8) {
                        Image("folder-plus")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                        Text("Move")
                            .font(.interMedium(size: 16))
                    }
                    .foregroundColor(.baseBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.warmGray200)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, bottomPadding)
            .background(Color.warmGray50)
        }
        .padding(.bottom, bottomSafeAreaPadding)
    }
}
