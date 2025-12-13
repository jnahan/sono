import SwiftUI

struct CollectionsRowView: View {
    let collection: Collection
    let recordingCount: Int
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Collection Icon
            ZStack {
                Circle()
                    .fill(Color.accent)
                    .frame(width: 36, height: 36)
                
                Image("waveform")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.accentLight)
            }
            
            // Collection Info
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(.dmSansSemiBold(size: 16))
                    .foregroundColor(.baseBlack)
                
                Text("\(recordingCount) recordings")
                    .font(.system(size: 14))
                    .foregroundColor(.warmGray500)
            }
            
            Spacer()
            
            // Three-dot menu
            ActionButton(
                icon: "dots-three-bold",
                iconSize: 24,
                frameSize: 32,
                actions: [
                    ActionItem(title: "Rename", icon: "pencil-simple", action: onRename),
                    ActionItem(title: "Delete", icon: "trash", action: onDelete, isDestructive: true)
                ]
            )
        }
        .padding(.top, 8)
    }
}





