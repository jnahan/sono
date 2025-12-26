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
    let onSettingsTap: () -> Void
    let onAddCollection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header - "Sono"
            Text("Sono")
                .font(.dmSansSemiBold(size: 24))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.top, 80)
                .padding(.bottom, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Group 1: Default filters
                    VStack(spacing: 4) {
                        Button { onSelectAll() } label: {
                            DrawerRow(
                                icon: "waveform",
                                title: "All recordings",
                                isSelected: selectedFilter == .all,
                                isDefaultFilter: true
                            )
                        }
                        .buttonStyle(.plain)

                        Button { onSelectUnorganized() } label: {
                            DrawerRow(
                                icon: "folder-open",
                                title: "Unorganized recordings",
                                isSelected: selectedFilter == .unorganized,
                                isDefaultFilter: true
                            )
                        }
                        .buttonStyle(.plain)

                        Button { onSettingsTap() } label: {
                            DrawerRow(
                                icon: "gear-six",
                                title: "Settings",
                                isSelected: false,
                                isDefaultFilter: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Group 2: User collections with title
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Collections")
                            .font(.dmSansMedium(size: 14))
                            .foregroundColor(.blueGray700)
                            .padding(.horizontal, 12)

                        VStack(spacing: 4) {
                            // Add collection button - always visible
                            Button {
                                onAddCollection()
                            } label: {
                                HStack(spacing: 8) {
                                    Image("folder-plus")
                                        .resizable()
                                        .renderingMode(.template)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.blueGray700)

                                    Text("Add collection")
                                        .font(.dmSansMedium(size: 16))
                                        .foregroundColor(.blueGray700)

                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.clear)
                                .cornerRadius(8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            // Existing collections
                            ForEach(collections) { collection in
                                Button {
                                    onSelectCollection(collection)
                                } label: {
                                    DrawerRow(
                                        title: collection.name,
                                        recordingCount: recordings.filter {
                                            $0.collections.contains { $0.id == collection.id }
                                        }.count,
                                        isSelected: selectedFilter == .collection(collection),
                                        isDefaultFilter: false,
                                        onRename: { onRename(collection) },
                                        onDelete: { onDelete(collection) }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 300)
        .background(Color.blueGray100)
    }
}

// MARK: - Drawer Row Component

private struct DrawerRow: View {
    var icon: String? = nil
    let title: String
    var recordingCount: Int? = nil
    let isSelected: Bool
    let isDefaultFilter: Bool
    var onRename: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            // Icon for default filters
            if let icon = icon {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.blueGray700)
            }

            // Title
            if let count = recordingCount {
                Text("\(title) (\(count))")
                    .font(.dmSansMedium(size: 16))
                    .foregroundColor(isDefaultFilter ? .blueGray700 : .black)
            } else {
                Text(title)
                    .font(.dmSansMedium(size: 16))
                    .foregroundColor(isDefaultFilter ? .blueGray700 : .black)
            }

            Spacer()

            // Dots three menu for custom collections
            if !isDefaultFilter, let onRename = onRename, let onDelete = onDelete {
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blueGray200 : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
}
