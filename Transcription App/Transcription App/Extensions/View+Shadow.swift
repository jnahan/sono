import SwiftUI

extension View {
    // default shadow
    func appShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 4)
    }
}
