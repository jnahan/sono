import SwiftUI

// MARK: - Button Variant

enum ButtonVariant {
    case primary    // Black background, white text
    case warning    // Warning color background, white text
    case ghost      // Transparent background, black text
    case white      // White background with border, black text

    var backgroundColor: Color {
        switch self {
        case .primary: return .baseBlack
        case .warning: return .warning
        case .ghost: return .clear
        case .white: return .baseWhite
        }
    }

    var disabledBackgroundColor: Color {
        switch self {
        case .primary, .warning: return .warmGray400
        case .ghost: return .clear
        case .white: return .warmGray200
        }
    }

    var foregroundColor: Color {
        switch self {
        case .primary, .warning: return .baseWhite
        case .ghost, .white: return .baseBlack
        }
    }

    var disabledForegroundColor: Color {
        .warmGray400
    }

    var hasBorder: Bool {
        self == .white
    }
}

// MARK: - Base Button Style

struct BaseButtonStyle: ButtonStyle {
    let variant: ButtonVariant
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dmSansSemiBold(size: 16))
            .foregroundColor(isEnabled ? variant.foregroundColor : variant.disabledForegroundColor)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
            .padding(.horizontal, 64)
            .background(
                (isEnabled ? variant.backgroundColor : variant.disabledBackgroundColor)
                   .opacity(configuration.isPressed ? 0.7 : 1)
            )
            .cornerRadius(.infinity)
            .if(variant.hasBorder) { view in
                view.overlay(
                    RoundedRectangle(cornerRadius: .infinity)
                        .stroke(Color.warmGray200, lineWidth: 1)
                )
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }
}

// MARK: - Convenience Button Styles

struct AppButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        BaseButtonStyle(variant: .primary).makeBody(configuration: configuration)
    }
}

struct WarningButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        BaseButtonStyle(variant: .warning).makeBody(configuration: configuration)
    }
}

struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        BaseButtonStyle(variant: .ghost).makeBody(configuration: configuration)
    }
}

struct WhiteButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        BaseButtonStyle(variant: .white).makeBody(configuration: configuration)
    }
}
