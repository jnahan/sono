import SwiftUI

struct SettingsRow: View {
    let title: String
    let value: String?
    let imageName: String
    var showChevron: Bool = true
    
    var body: some View {
        HStack(spacing: 16) {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(.baseBlack)

            Text(title)
                .font(.system(size: 17))
                .foregroundColor(.baseBlack)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.system(size: 17))
                    .foregroundColor(.warmGray500)
            }
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.warmGray400)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
