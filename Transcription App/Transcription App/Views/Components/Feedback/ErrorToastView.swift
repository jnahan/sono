import SwiftUI

struct ErrorToastView: View {
    let message: String
    @Binding var isPresented: Bool

    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding()
            .background(Color.warning)
            .cornerRadius(10)
            .offset(y: dragOffset)
            .opacity(1 - Double(min(abs(dragOffset) / 100, 1)))
            .gesture(
                DragGesture(minimumDistance: 10)
                    .updating($dragOffset) { value, state, _ in
                        // Only allow upward swipe
                        if value.translation.height < 0 {
                            state = value.translation.height
                        }
                    }
                    .onChanged { _ in
                        isDragging = true
                    }
                    .onEnded { value in
                        isDragging = false
                        // Dismiss if swiped up more than 50 points
                        if value.translation.height < -50 {
                            isPresented = false
                        }
                    }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
            .onAppear {
                // Auto-dismiss after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    isPresented = false
                }
            }
    }
}


