import SwiftUI

struct ToastView: View {
    let message: String
    var isPresented: Binding<Bool>?
    let isError: Bool

    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    init(message: String, isPresented: Binding<Bool>? = nil, isError: Bool = false) {
        self.message = message
        self.isPresented = isPresented
        self.isError = isError
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.dmSansMedium(size: 14))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(12)
        .background(isError ? Color.warning : Color.black)
        .cornerRadius(12)
        .padding(.horizontal, 20)
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
                        isPresented?.wrappedValue = false
                    }
                }
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // Auto-dismiss after 3 seconds if isPresented binding is provided
            if let isPresented = isPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    isPresented.wrappedValue = false
                }
            }
        }
    }
}
