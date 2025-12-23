//
//  CollectionDrawerView.swift
//

import SwiftUI
import SwiftData

struct CollectionDrawerView: View {
    let collections: [Collection]
    let recordings: [Recording]
    let selectedFilter: CollectionFilter

    let onSelectAll: () -> Void
    let onSelectUnorganized: () -> Void
    let onSelectCollection: (Collection) -> Void
    let onRename: (Collection) -> Void
    let onDelete: (Collection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Collections")
                .font(.dmSansSemiBold(size: 18))
                .foregroundColor(.baseBlack)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 0) {

                    Button { onSelectAll() } label: {
                        HStack {
                            Text("All recordings")
                                .font(.dmSansMedium(size: 16))
                                .foregroundColor(.baseBlack)

                            Spacer()

                            if selectedFilter == .all {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.baseBlack)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    Button { onSelectUnorganized() } label: {
                        HStack {
                            Text("Unorganized recordings")
                                .font(.dmSansMedium(size: 16))
                                .foregroundColor(.baseBlack)

                            Spacer()

                            if selectedFilter == .unorganized {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.baseBlack)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.vertical, 8)

                    ForEach(collections) { collection in
                        Button { onSelectCollection(collection) } label: {
                            CollectionsRowView(
                                collection: collection,
                                recordingCount: recordings.filter {
                                    $0.collections.contains(where: { $0.id == collection.id })
                                }.count,
                                onRename: { onRename(collection) },
                                onDelete: { onDelete(collection) }
                            )
                            .padding(.horizontal, 20)
                            .background(
                                (selectedFilter == .collection(collection))
                                ? Color.warmGray50
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
        .frame(maxHeight: .infinity)
        .frame(width: 300)
        .background(Color.warmGray100) 
        .ignoresSafeArea(edges: .vertical)
    }
}
