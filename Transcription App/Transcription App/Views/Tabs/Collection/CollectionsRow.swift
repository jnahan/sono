import SwiftUI

struct CollectionsRow: View {
    let folder: Folder
    let recordingCount: Int
    let onRename: () -> Void
    let onDelete: () -> Void
    
    @State private var showMenu = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Folder Icon
            ZStack {
                Circle()
                    .fill(Color.accentLight)
                    .frame(width: 40, height: 40)
                
                Image("waveform")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.accent)
            }
            
            // Folder Info
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.interMedium(size: 16))
                    .foregroundColor(.baseBlack)
                
                Text("\(recordingCount) recordings")
                    .font(.system(size: 14))
                    .foregroundColor(.warmGray500)
            }
            
            Spacer()
            
            // Three-dot menu
            Button {
                showMenu = true
            } label: {
                Image("dots-three")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.warmGray500)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Rename") {
                onRename()
            }
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
            
            Button("Cancel", role: .cancel) {}
        }
    }
}
