import SwiftUI

struct ToastView: View {
    let message: String
    var isPresented: Binding<Bool>?
    let isError: Bool
    
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
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // Auto-dismiss after 4 seconds if isPresented binding is provided
            if let isPresented = isPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation {
                        isPresented.wrappedValue = false
                    }
                }
            }
        }
    }
}
