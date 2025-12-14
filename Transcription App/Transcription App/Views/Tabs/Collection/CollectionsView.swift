import SwiftUI
import SwiftData

struct CollectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query(sort: \Collection.createdAt, order: .reverse) private var collections: [Collection]
    @Query(sort: \Recording.recordedAt, order: .reverse) private var recordings: [Recording]
    
    @State private var showCreateCollection = false
    @State private var newCollectionName = ""
    @State private var searchText = ""
    @State private var selectedCollection: Collection?
    @State private var showSettings = false
    @State private var editingCollection: Collection?
    @State private var editCollectionName = ""
    @State private var deletingCollection: Collection?
    
    private var filteredCollections: [Collection] {
        let sortedCollections = collections.sorted { $0.createdAt > $1.createdAt }
        
        if searchText.isEmpty {
            return sortedCollections
        } else {
            return sortedCollections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
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
                                .padding(.horizontal, AppConstants.UI.Spacing.large)
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
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.warmGray50)
                                .listRowInsets(EdgeInsets(top: 10, leading: AppConstants.UI.Spacing.large, bottom: 10, trailing: AppConstants.UI.Spacing.large))
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
                .navigationBarHidden(true)
            .onAppear {
                // Reset navigation state when returning to this tab
                selectedCollection = nil
                // Show tab bar on root view
                showPlusButton.wrappedValue = true
            }
            .navigationDestination(item: $selectedCollection) { collection in
                CollectionDetailView(
                    collection: collection,
                    showPlusButton: showPlusButton
                )
                .onAppear { showPlusButton.wrappedValue = false }
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

                        do {
                            try modelContext.save()
                        } catch {
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
                    let collectionRecordingCount = recordings.filter { $0.collection?.id == collection.id }.count
                    ConfirmationSheet(
                        isPresented: Binding(
                            get: { deletingCollection != nil },
                            set: { if !$0 { deletingCollection = nil } }
                        ),
                        title: "Delete collection?",
                        message: "Are you sure you want to delete \"\(collection.name)\"? This will remove all \(collectionRecordingCount) recording\(collectionRecordingCount == 1 ? "" : "s") in this collection.",
                        confirmButtonText: "Delete collection",
                        cancelButtonText: "Cancel",
                        onConfirm: {
                            // Delete all recordings in this collection
                            let recordingsInCollection = recordings.filter { $0.collection?.id == collection.id }

                            // Cancel any active transcriptions before deleting
                            for recording in recordingsInCollection {
                                TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)
                            }

                            for recording in recordingsInCollection {
                                modelContext.delete(recording)
                            }

                            // Now delete the collection
                            modelContext.delete(collection)

                            do {
                                try modelContext.save()
                            } catch {
                                Logger.error("CollectionsView", "Failed to save collection deletion: \(error.localizedDescription)")
                            }

                            deletingCollection = nil
                        }
                    )
                }
            }
        }
    }

    private func recordingCount(for collection: Collection) -> Int {
        recordings.filter { $0.collection?.id == collection.id }.count
    }
    
    private func createCollection() {
        guard !newCollectionName.isEmpty else { return }
        
        let collection = Collection(name: newCollectionName)
        modelContext.insert(collection)
        newCollectionName = ""
        showCreateCollection = false
    }
}

#Preview {
    CollectionsView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Collection.self], inMemory: true)
}
