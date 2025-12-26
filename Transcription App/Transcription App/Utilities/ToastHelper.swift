import SwiftUI

/// Helper for managing toast display with auto-dismiss
enum ToastHelper {

    /// Shows a toast and automatically dismisses it after a delay
    /// - Parameters:
    ///   - binding: Binding to the boolean controlling toast visibility
    ///   - delay: Delay in seconds before auto-dismissing (default: 2.0)
    static func show(_ binding: Binding<Bool>, delay: TimeInterval = 2.0) {
        withAnimation { binding.wrappedValue = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation { binding.wrappedValue = false }
        }
    }
}
