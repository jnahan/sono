import SwiftUI

struct CustomTopBar: View {
    let title: String
    let leftIcon: String?
    let rightIcon: String?
    let onLeftTap: (() -> Void)?
    let onRightTap: (() -> Void)?
    
    init(
        title: String,
        leftIcon: String? = nil,
        rightIcon: String? = nil,
        onLeftTap: (() -> Void)? = nil,
        onRightTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.leftIcon = leftIcon
        self.rightIcon = rightIcon
        self.onLeftTap = onLeftTap
        self.onRightTap = onRightTap
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left button
            if let leftIcon = leftIcon {
                Button {
                    onLeftTap?()
                } label: {
                    Image(leftIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.warmGray400)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            } else {
                Spacer()
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // Title
            Text(title)
                .font(.custom("LibreBaskerville-Regular", size: 18))
                .foregroundColor(.baseBlack)
            
            Spacer()
            
            // Right button
            if let rightIcon = rightIcon {
                Button {
                    onRightTap?()
                } label: {
                    Image(rightIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.warmGray400)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, 8)
            } else {
                Spacer()
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(height: 68)
    }
}
