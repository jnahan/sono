import SwiftUI

extension View {
    /// Applies compact sheet presentation styling (for forms/pickers)
    /// - Parameter height: Fixed height for the sheet
    /// - Returns: View with compact sheet presentation modifiers applied
    func compactSheetStyle(height: CGFloat) -> some View {
        self
            .presentationDetents([.height(height)])
            .presentationCompactAdaptation(.none)
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.white)
            .presentationCornerRadius(16)
            .interactiveDismissDisabled(false)
    }
}
