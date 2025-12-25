import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    
    var body: some View {
        HStack(spacing: 8) {
            Image("magnifying-glass")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundColor(.blueGray500)
            
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.blueGray400)
                        .font(.system(size: 16))
                }
                
                TextField("", text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(.baseBlack)
            }
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image("x-circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(.blueGray500)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.baseWhite)
        .cornerRadius(32)
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color.blueGray200, lineWidth: 1)
        )
        .zIndex(1)
        
    }
}
