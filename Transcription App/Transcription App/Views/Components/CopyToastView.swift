import SwiftUI

struct CopyToastView: View {
    var body: some View {
        Text("Copied transcription")
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .shadow(radius: 5)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }
}





