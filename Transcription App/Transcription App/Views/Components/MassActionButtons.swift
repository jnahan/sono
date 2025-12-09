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
                Button(action: onMove) {
                    Image("folder-open")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.baseBlack)
                }

                Spacer()

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 24))
                        .foregroundColor(.baseBlack)
                }

                Spacer()

                // Copy button
                Button(action: onCopy) {
                    Image("copy")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.baseBlack)
                }

                Spacer()

                // Export button
                Button(action: onExport ?? {}) {
                    Image("export")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.baseBlack)
                }
                .disabled(onExport == nil)
                .opacity(onExport == nil ? 0.3 : 1.0)
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 48)
            .background(Color.warmGray50)
        }
        .padding(.bottom, bottomSafeAreaPadding)
    }
}
