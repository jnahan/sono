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
                .foregroundColor(.warmGray500)
            
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.warmGray400)
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
                        .foregroundColor(.warmGray500)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.baseWhite)
        .cornerRadius(32)
        .zIndex(1)
        .appShadow()

    }
}

#Preview {
    VStack(spacing: 20) {
        SearchBar(text: .constant(""))
            .padding()
        
        SearchBar(text: .constant("Test search"))
            .padding()
    }
}
