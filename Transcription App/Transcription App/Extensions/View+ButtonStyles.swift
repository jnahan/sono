import SwiftUI

struct AppButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dmSansSemiBold(size: 16))
            .foregroundColor(.baseWhite)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
            .padding(.horizontal, 64)
            .background(
                (isEnabled ? Color.baseBlack : Color.warmGray400)
                   .opacity(configuration.isPressed ? 0.7 : 1)
            )
            .cornerRadius(.infinity)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }
}

struct WarningButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dmSansSemiBold(size: 16))
            .foregroundColor(.baseWhite)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
            .padding(.horizontal, 64)
            .background(
                (isEnabled ? Color.warning : Color.warmGray400)
                   .opacity(configuration.isPressed ? 0.7 : 1)
            )
            .cornerRadius(.infinity)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }
}

struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dmSansSemiBold(size: 16))
            .foregroundColor(isEnabled ? .baseBlack : .warmGray400)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
            .padding(.horizontal, 64)
            .background(Color.clear)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }
}

struct WhiteButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dmSansSemiBold(size: 16))
            .foregroundColor(isEnabled ? .baseBlack : .warmGray400)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
            .padding(.horizontal, 64)
            .background(
                (isEnabled ? Color.baseWhite : Color.warmGray200)
                   .opacity(configuration.isPressed ? 0.7 : 1)
            )
            .cornerRadius(.infinity)
            .overlay(
                RoundedRectangle(cornerRadius: .infinity)
                    .stroke(Color.warmGray200, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }
}

