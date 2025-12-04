import SwiftUI

struct InputLabel: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.warmGray500)
    }
}

struct InputField: View {
    @Binding var text: String
    var placeholder: String = ""
    var isMultiline: Bool = false
    var height: CGFloat? = nil
    var showChevron: Bool = false
    var onTap: (() -> Void)? = nil
    var error: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let onTap = onTap {
                    // Tappable field (for folder picker)
                    Button(action: onTap) {
                        HStack {
                            Text(text.isEmpty ? placeholder : text)
                                .font(.system(size: 17))
                                .foregroundColor(text.isEmpty ? .warmGray400 : .baseBlack)
                            Spacer()
                            if showChevron {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.warmGray400)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(error != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                    }
                } else if isMultiline {
                    // TextEditor
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 17))
                                .foregroundColor(.warmGray400)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                        }
                        
                        TextEditor(text: $text)
                            .font(.system(size: 17))
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(Color.white)
                            .cornerRadius(12)
                            .frame(height: height ?? 200)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(error != nil ? Color.red : Color.clear, lineWidth: 1)
                    )
                } else {
                    // TextField
                    TextField(placeholder, text: $text)
                        .font(.system(size: 17))
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(error != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                }
            }
            
            // Error message
            if let error = error {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
        }
    }
}
