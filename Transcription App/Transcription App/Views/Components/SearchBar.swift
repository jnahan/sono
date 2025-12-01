import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.warmGray400)
                .font(.system(size: 18))
            
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
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.warmGray400)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.baseWhite)
        .cornerRadius(32)
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
