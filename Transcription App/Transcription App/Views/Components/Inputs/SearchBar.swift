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
                    .foregroundColor(.black)
            }
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image("x-circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.blueGray500)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.blueGray50)
        .cornerRadius(32)
        .zIndex(1)
        
    }
}
