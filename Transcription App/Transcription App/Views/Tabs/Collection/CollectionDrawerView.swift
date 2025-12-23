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

            // Header
            Text("Collections")
                .font(.dmSansSemiBold(size: 18))
                .foregroundColor(.baseBlack)
                .padding(.horizontal, 20)
                .padding(.top, 80)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 0) {

                    Button { onSelectAll() } label: {
                        row(
                            title: "All recordings",
                            isSelected: selectedFilter == .all
                        )
                    }

                    Button { onSelectUnorganized() } label: {
                        row(
                            title: "Unorganized recordings",
                            isSelected: selectedFilter == .unorganized
                        )
                    }

                    Divider()
                        .padding(.vertical, 8)

                    ForEach(collections) { collection in
                        Button {
                            onSelectCollection(collection)
                        } label: {
                            CollectionsRowView(
                                collection: collection,
                                recordingCount: recordings.filter {
                                    $0.collections.contains { $0.id == collection.id }
                                }.count,
                                onRename: { onRename(collection) },
                                onDelete: { onDelete(collection) }
                            )
                            .padding(.horizontal, 20)
                            .background(
                                selectedFilter == .collection(collection)
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
        .frame(width: 300)
        .background(Color.warmGray100)
    }

    // MARK: - Shared Row

    private func row(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
                .font(.dmSansMedium(size: 16))
                .foregroundColor(.baseBlack)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.baseBlack)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
