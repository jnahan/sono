import SwiftUI

struct CopyToastView: View {
    var body: some View {
        Text("Recording copied")
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .shadow(radius: 5)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }
}



