import SwiftUI

struct CollectionsRowView: View {
    let collection: Collection
    let recordingCount: Int
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {

            // Collection Info
            Text("\(collection.name) (\(recordingCount))")
                .font(.dmSansMedium(size: 16))
                .foregroundColor(.baseBlack)

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
        .padding(.vertical, 8)
    }
}
