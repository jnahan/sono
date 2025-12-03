import SwiftUI
import SwiftData

struct CollectionFormSheet: View {
    @Binding var isPresented: Bool
    @Binding var folderName: String
    let isEditing: Bool
    let onSave: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.warmGray300)
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Title
            Text(isEditing ? "Rename folder" : "Create folder")
                .font(.custom("LibreBaskerville-Regular", size: 24))
                .foregroundColor(.baseBlack)
                .padding(.bottom, 32)
            
            // Text field
            VStack(alignment: .leading, spacing: 8) {
                InputLabel(text: "Folder name")
                    .padding(.horizontal, 24)
                
                InputField(text: $folderName, placeholder: "Folder name")
                    .padding(.horizontal, 24)
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        if !folderName.isEmpty {
                            onSave()
                            isPresented = false
                        }
                    }
            }
            .padding(.bottom, 32)
            
            // Save button
            Button {
                onSave()
                isPresented = false
            } label: {
                Text(isEditing ? "Save changes" : "Create folder")
            }
            .disabled(folderName.isEmpty)
            .buttonStyle(AppButtonStyle())
        }
        .background(Color.warmGray100)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.warmGray100)
        .presentationCornerRadius(24)
        .onAppear {
            #if !os(macOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
            #endif
        }
    }
}
