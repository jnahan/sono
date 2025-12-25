import SwiftUI

/// Reusable component for displaying collection tags
struct CollectionTagsView: View {
    let collections: [Collection]
    var maxVisible: Int = 3

    var body: some View {
        if !collections.isEmpty {
            HStack(spacing: 4) {
                ForEach(collections.prefix(maxVisible), id: \.id) { collection in
                    Text("#\(collection.name)")
                        .font(.system(size: 12))
                        .foregroundColor(.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(Color.accentLight)
                        .cornerRadius(4)
                }

                if collections.count > maxVisible {
                    Text("+\(collections.count - maxVisible)")
                        .font(.system(size: 12))
                        .foregroundColor(.blueGray700)
                }
            }
        }
    }
}
