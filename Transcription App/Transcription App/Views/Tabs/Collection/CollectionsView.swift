import SwiftUI
import SwiftData

struct CollectionsView: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var navDepth: Int

    @Query(sort: \Collection.createdAt, order: .reverse) private var collections: [Collection]
    @Query(sort: \Recording.recordedAt, order: .reverse) private var recordings: [Recording]

    @State private var showCreateCollection = false
    @State private var newCollectionName = ""
    @State private var searchText = ""
    @State private var selectedCollection: Collection?
    @State private var editingCollection: Collection?
    @State private var editCollectionName = ""
    @State private var deletingCollection: Collection?

    private var filteredCollections: [Collection] {
        let sortedCollections = collections.sorted { $0.createdAt > $1.createdAt }
        if searchText.isEmpty { return sortedCollections }
        return sortedCollections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                CustomTopBar(
                    title: "Collections",
                    rightIcon: "folder-plus",
                    onRightTap: { showCreateCollection = true }
                )

                VStack(alignment: .leading, spacing: 12) {
                    if !collections.isEmpty {
                        SearchBar(text: $searchText, placeholder: "Search collections...")
                            .padding(.horizontal, 20)
                    }

                    if collections.isEmpty {
                        CollectionsEmptyStateView(showCreateCollection: $showCreateCollection)
                    } else {
                        List {
                            ForEach(filteredCollections) { collection in
                                Button {
                                    selectedCollection = collection
                                } label: {
                                    CollectionsRowView(
                                        collection: collection,
                                        recordingCount: recordingCount(for: collection),
                                        onRename: {
                                            editingCollection = collection
                                            editCollectionName = collection.name
                                        },
                                        onDelete: {
                                            deletingCollection = collection
                                        }
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.warmGray50)
                                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .contentMargins(.bottom, 80, for: .scrollContent)
                    }
                }
                .padding(.top, 8)
            }
        }
        .background(Color.warmGray50.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { selectedCollection = nil }

        // ✅ Push detail (track depth)
        .navigationDestination(item: $selectedCollection) { collection in
            CollectionDetailView(collection: collection, navDepth: $navDepth)
                .trackNavDepth($navDepth)
        }

        .sheet(isPresented: $showCreateCollection) {
            CollectionFormSheet(
                isPresented: $showCreateCollection,
                collectionName: $newCollectionName,
                isEditing: false,
                onSave: createCollection,
                existingCollections: collections,
                currentCollection: nil
            )
        }

        .sheet(isPresented: Binding(
            get: { editingCollection != nil },
            set: { if !$0 { editingCollection = nil } }
        )) {
            CollectionFormSheet(
                isPresented: Binding(
                    get: { editingCollection != nil },
                    set: { if !$0 { editingCollection = nil } }
                ),
                collectionName: $editCollectionName,
                isEditing: true,
                onSave: {
                    editingCollection?.name = editCollectionName
                    do { try modelContext.save() } catch {
                        Logger.error("CollectionsView", "Failed to save collection rename: \(error.localizedDescription)")
                    }
                    editingCollection = nil
                },
                existingCollections: collections,
                currentCollection: editingCollection
            )
        }

        .sheet(isPresented: Binding(
            get: { deletingCollection != nil },
            set: { if !$0 { deletingCollection = nil } }
        )) {
            if let collection = deletingCollection {
                ConfirmationSheet(
                    isPresented: Binding(
                        get: { deletingCollection != nil },
                        set: { if !$0 { deletingCollection = nil } }
                    ),
                    title: "Delete collection?",
                    message: "Are you sure you want to delete \"\(collection.name)\"? Recordings in this collection will remain in your library.",
                    confirmButtonText: "Delete collection",
                    cancelButtonText: "Cancel",
                    onConfirm: {
                        modelContext.delete(collection)
                        do { try modelContext.save() } catch {
                            Logger.error("CollectionsView", "Failed to save collection deletion: \(error.localizedDescription)")
                        }
                        deletingCollection = nil
                    }
                )
            }
        }
    }

    private func recordingCount(for collection: Collection) -> Int {
        recordings.filter { recording in
            recording.collections.contains(where: { $0.id == collection.id })
        }.count
    }

    private func createCollection() {
        guard !newCollectionName.isEmpty else { return }
        let collection = Collection(name: newCollectionName)
        modelContext.insert(collection)
        newCollectionName = ""
        showCreateCollection = false
    }
}
