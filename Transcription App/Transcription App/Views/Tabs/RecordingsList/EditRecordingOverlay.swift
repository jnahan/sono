import SwiftUI

struct EditRecordingOverlay: View {
    @Binding var isPresented: Bool
    @Binding var newTitle: String
    let onSave: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 20) {
                Text("Edit Recording Title")
                    .font(.headline)
                
                TextField("New Title", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save", action: onSave)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .frame(maxWidth: 400)
            .shadow(radius: 20)
        }
    }
}
