import SwiftUI

/// Reusable mass action buttons component for selection mode
/// Displays icon-only buttons for Move, Delete, Copy, and Export
struct MassActionButtons: View {
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onMove: () -> Void
    var onExport: (() -> Void)? = nil
    var isDisabled: Bool = false

    var horizontalPadding: CGFloat = AppConstants.UI.Spacing.large
    var bottomPadding: CGFloat = 0
    var bottomSafeAreaPadding: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Top stroke only
            Rectangle()
                .fill(Color.warmGray200)
                .frame(height: 1)

            // Icon buttons
            HStack(spacing: 0) {
                // Move button
                IconButton(icon: "folder-open", action: onMove)
                    .disabled(isDisabled)
                    .opacity(isDisabled ? 0.3 : 1.0)

                Spacer()

                // Delete button
                IconButton(icon: "trash", action: onDelete)
                    .disabled(isDisabled)
                    .opacity(isDisabled ? 0.3 : 1.0)

                Spacer()

                // Copy button
                IconButton(icon: "copy", action: onCopy)
                    .disabled(isDisabled)
                    .opacity(isDisabled ? 0.3 : 1.0)

                Spacer()

                // Export button
                IconButton(icon: "export", action: onExport ?? {})
                    .disabled(isDisabled || onExport == nil)
                    .opacity((isDisabled || onExport == nil) ? 0.3 : 1.0)
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Safe area padding with background
            if bottomSafeAreaPadding > 0 {
                Spacer()
                    .frame(height: bottomSafeAreaPadding)
            }
        }
        .background(Color.warmGray50)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
