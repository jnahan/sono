import SwiftUI

struct AskSonoEmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hi there!\nHow can I help you?")
                .font(.dmSansMedium(size: 20))
                .foregroundColor(.baseBlack)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Ideas")
                .font(.dmSansMedium(size: 16))
                .foregroundColor(.blueGray500)
                .padding(.top, 24)
            
            VStack(alignment: .leading, spacing: 16) {
                IdeaItem(
                    icon: "seal-question",
                    iconColor: .pink,
                    text: "Ask a question"
                )
                
                IdeaItem(
                    icon: "pen-nib",
                    iconColor: .teal,
                    text: "Request rewrite"
                )
                
                IdeaItem(
                    icon: "check-circle",
                    iconColor: .accent,
                    text: "Get action items"
                )
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Idea Item

private struct IdeaItem: View {
    let icon: String
    let iconColor: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(iconColor)
            
            Text(text)
                .font(.dmSansMedium(size: 16))
                .foregroundColor(.baseBlack)
        }
    }
}

