import SwiftUI

// MARK: - Global Action Sheet Manager

/// Global manager for presenting action sheets at the app level
class ActionSheetManager: ObservableObject {
    static let shared = ActionSheetManager()

    @Published var isPresented = false
    @Published var actions: [ActionItem] = []

    private init() {}

    func show(actions: [ActionItem]) {
        self.actions = actions
        self.isPresented = true
    }

    func dismiss() {
        self.isPresented = false
    }
}

/// Wrapper view for dots three menu - matches NewRecordingSheet structure exactly
struct DotsThreeSheet: View {
    @Binding var isPresented: Bool
    let actions: [ActionItem]

    var body: some View {
        ActionSheet(
            actions: actions,
            isPresented: $isPresented
        )
    }
}

/// Action item for ActionButton menu
struct ActionItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String?
    let action: () -> Void
    var isDestructive: Bool = false
    var tintColor: Color? = nil
}

/// Custom action button component that shows a menu with actions
/// Replaces native iOS confirmationDialog with a custom menu
struct ActionButton: View {
    let icon: String
    var iconSize: CGFloat = 24
    var frameSize: CGFloat = 32
    let actions: [ActionItem]

    var body: some View {
        Button {
            ActionSheetManager.shared.show(actions: actions)
        } label: {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(.warmGray500)
                .frame(width: frameSize, height: frameSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Unified action sheet component with overlay style
struct ActionSheet: View {
    let actions: [ActionItem]
    @Binding var isPresented: Bool
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 300

    init(actions: [ActionItem], isPresented: Binding<Bool>) {
        self.actions = actions
        self._isPresented = isPresented
    }

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
                            // Action items
                            actionItemsView(actions: actions)

                            // Cancel button
                            Button {
                                dismissSheet()
                            } label: {
                                Text("Cancel")
                            }
                            .buttonStyle(WhiteButtonStyle())
                            .padding(.top, 16)
                        }
                        .offset(y: offset)
                        .opacity(opacity)
                    }
                }
                .opacity(opacity)
                .onTapGesture {
                    dismissSheet()
                }
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                opacity = 1
                offset = 0
            }
        }
    }

    private func dismissSheet() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            opacity = 0
            offset = 300
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isPresented = false
        }
    }
    
    @ViewBuilder
    private func actionItemsView(actions: [ActionItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(actions) { action in
                Button {
                    action.action()
                    dismissSheet()
                } label: {
                    HStack(spacing: 12) {
                        if let icon = action.icon {
                            Image(icon)
                                .resizable()
                                .renderingMode(.template)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(
                                    action.tintColor ?? (action.isDestructive ? .warning : .baseBlack)
                                )
                        }

                        Text(action.title)
                            .font(.dmSansMedium(size: 16))
                            .foregroundColor(action.isDestructive ? .warning : .baseBlack)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .background(Color.baseWhite)
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}

