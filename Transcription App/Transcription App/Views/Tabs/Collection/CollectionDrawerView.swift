import SwiftUI
import SwiftData

struct CollectionDrawerView: View {
    let collections: [Collection]
    let recordings: [Recording]
    let selectedCollection: Collection?

    let onSelectAll: () -> Void
    let onSelectCollection: (Collection) -> Void
    let onRename: (Collection) -> Void
    let onDelete: (Collection) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {

            // Scrim
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // Drawer
            VStack(alignment: .leading, spacing: 0) {

                Text("Collections")
                    .font(.dmSansSemiBold(size: 18))
                    .foregroundColor(.baseBlack)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 0) {

                        // All recordings
                        Button {
                            onSelectAll()
                            onClose()
                        } label: {
                            HStack {
                                Text("All recordings")
                                    .font(.dmSansMedium(size: 16))
                                    .foregroundColor(.baseBlack)
                                Spacer()
                                if selectedCollection == nil {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.vertical, 8)

                        // Collections
                        ForEach(collections) { collection in
                            Button {
                                onSelectCollection(collection)
                                onClose()
                            } label: {
                                CollectionsRowView(
                                    collection: collection,
                                    recordingCount: recordings.filter {
                                        $0.collections.contains(where: { $0.id == collection.id })
                                    }.count,
                                    onRename: {
                                        onRename(collection)
                                    },
                                    onDelete: {
                                        onDelete(collection)
                                    }
                                )
                                .padding(.horizontal, 20)
                                .background(
                                    selectedCollection?.id == collection.id
                                    ? Color.warmGray100
                                    : Color.clear
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Spacer(minLength: 0)
            }
            .frame(width: 300)
            .background(Color.warmGray50)
            .ignoresSafeArea(edges: .vertical)
        }
    }
}
