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
        HStack(alignment: .center, spacing: 0) {
            // Left button
            if let leftIcon = leftIcon {
                Button {
                    onLeftTap?()
                } label: {
                    Image(leftIcon)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .foregroundColor(.warmGray500)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
            } else {
                Spacer()
                    .frame(width: 40, height: 40)
            }

            
            Spacer()
            
            // Title
            Text(title)
                .font(.dmSansSemiBold(size: 16))
                .foregroundColor(.baseBlack)
            
            Spacer()
            
            // Right button
            if let rightIcon = rightIcon {
                Button {
                    onRightTap?()
                } label: {
                    Image(rightIcon)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .foregroundColor(.warmGray500)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
            } else {
                Spacer()
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, AppConstants.UI.Spacing.large)
        .padding(.vertical, 8)
        .frame(height: 56)
    }
}





