import SwiftUI

struct CollectionsEmptyState: View {
    @Binding var showCreateFolder: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 24) {
                Text("Organize your\nrecordings")
                    .font(.libreMedium(size: 24))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                
                Button {
                    showCreateFolder = true
                } label: {
                    HStack(spacing: 8) {
                        Image("folder-plus")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color.accent)
                        
                        Text("New collection")
                            .font(.system(size: 16))
                            .foregroundColor(Color.warmGray600)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .appShadow()
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
