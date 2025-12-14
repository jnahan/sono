import SwiftUI

// MARK: - View Extension for Conditional Modifiers

extension View {
    @ViewBuilder
    func `ifLet`<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

