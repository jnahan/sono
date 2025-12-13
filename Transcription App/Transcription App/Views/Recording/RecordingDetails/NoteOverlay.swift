import SwiftUI

struct NoteOverlay: View {
    @Binding var isPresented: Bool
    let noteText: String
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 300

    var body: some View {
        GeometryReader { _ in
            Color.black.opacity(0.0001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .background(Color.warmGray300.opacity(0.4))
                .edgesIgnoringSafeArea(.all)
                .overlay {
                    VStack(spacing: 0) {
                        Spacer()

                        VStack(spacing: 0) {
                            // Close button - 16px above note container
                            HStack {
                                Spacer()
                                Button {
                                    dismissOverlay()
                                } label: {
                                    Image("x")
                                        .resizable()
                                        .renderingMode(.template)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.warmGray500)
                                        .frame(width: 32, height: 32)
                                        .background(Color.baseWhite)
                                        .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)

                            // Note container
                            Text(noteText.isEmpty ? "No notes" : noteText)
                                .font(.dmSansRegular(size: 16))
                                .foregroundColor(.baseBlack)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 20)
                                .padding(.horizontal, 16)
                                .background(Color.warmGray50)
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                        }
                        .offset(y: offset)
                        .opacity(opacity)
                    }
                }
                .opacity(opacity)
                .onTapGesture {
                    dismissOverlay()
                }
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                opacity = 1
                offset = 0
            }
        }
    }

    private func dismissOverlay() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            opacity = 0
            offset = 300
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isPresented = false
        }
    }
}
