import SwiftUI

struct SettingsRow: View {
    let title: String
    let value: String?
    let imageName: String
    var showChevron: Bool = true
    var toggleBinding: Binding<Bool>? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(.baseBlack)

            Text(title)
                .font(.dmSansMedium(size: 16))
                .foregroundColor(.baseBlack)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.dmSansRegular(size: 16))
                    .foregroundColor(.blueGray600)
            }
            
            if let toggleBinding = toggleBinding {
                CustomSwitch(isOn: toggleBinding)
            } else if showChevron {
                Image("caret-right")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundColor(.blueGray400)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

