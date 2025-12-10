import SwiftUI

/// Reusable mass action buttons component for selection mode
/// Displays icon-only buttons for Move, Delete, Copy, and Export
struct MassActionButtons: View {
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onMove: () -> Void
    var onExport: (() -> Void)? = nil

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

                Spacer()

                // Delete button
                IconButton(icon: "trash", action: onDelete)

                Spacer()

                // Copy button
                IconButton(icon: "copy", action: onCopy)

                Spacer()

                // Export button
                IconButton(icon: "export", action: onExport ?? {})
                    .opacity(onExport == nil ? 0.3 : 1.0)
                    .disabled(onExport == nil)
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color.warmGray50)
        }
        .padding(.bottom, bottomSafeAreaPadding)
    }
}
