import SwiftUI

// MARK: - Input Field Styling

private struct InputFieldStyle: ViewModifier {
    let hasError: Bool

    func body(content: Content) -> some View {
        content
            .background(Color.baseWhite)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hasError ? Color.red : Color.warmGray200, lineWidth: 1)
            )
    }
}

// MARK: - Input Label

struct InputLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.warmGray700)
    }
}

// MARK: - Input Field

struct InputField: View {
    @Binding var text: String
    var placeholder: String = ""
    var isMultiline: Bool = false
    var height: CGFloat? = nil
    var showChevron: Bool = false
    var onTap: (() -> Void)? = nil
    var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let onTap = onTap {
                    tappableField(onTap: onTap)
                } else if isMultiline {
                    multilineField
                } else {
                    textField
                }
            }
            .modifier(InputFieldStyle(hasError: error != nil))

            if let error = error {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Field Types

    private func tappableField(onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack {
                Text(text.isEmpty ? placeholder : text)
                    .font(.system(size: 16))
                    .foregroundColor(text.isEmpty ? .warmGray400 : .baseBlack)
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16))
                        .foregroundColor(.warmGray400)
                }
            }
            .padding(16)
        }
    }

    private var multilineField: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 16))
                .foregroundColor(.baseBlack)
                .tint(.baseBlack)
                .scrollContentBackground(.hidden)
                .frame(height: height ?? 200)
                .scrollDismissesKeyboard(.interactively)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)

            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 16))
                    .foregroundColor(.warmGray400)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    private var textField: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.warmGray400))
            .font(.system(size: 16))
            .foregroundColor(.baseBlack)
            .tint(.baseBlack)
            .padding(16)
    }
}
