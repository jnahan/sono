import SwiftUI

/// A reusable gradient background component for empty states
struct EmptyStateGradientView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image("radial-gradient")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 280)
                .frame(maxWidth: .infinity)
                .rotationEffect(.degrees(180))
                .clipped()
            
            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }
}






