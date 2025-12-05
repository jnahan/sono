import SwiftUI
import SwiftData

struct CollectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showPlusButton) private var showPlusButton
    @Query private var collections: [Collection]
    @Query private var recordings: [Recording]
    
    @State private var showCreateCollection = false
    @State private var newCollectionName = ""
    @State private var searchText = ""
    @State private var selectedCollection: Collection?
    @State private var showSettings = false
    @State private var editingCollection: Collection?
    @State private var editCollectionName = ""
    @State private var deletingCollection: Collection?
    
    private var filteredCollections: [Collection] {
        if searchText.isEmpty {
            return collections
        } else {
            return collections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient at absolute top of screen (when empty)
                if collections.isEmpty {
                    EmptyStateGradient()
                }
                
                VStack(spacing: 0) {
                    CustomTopBar(
                        title: "Collections",
                        rightIcon: "folder-plus",
                        onRightTap: { showCreateCollection = true }
                    )
                    
                    if !collections.isEmpty {
                        SearchBar(text: $searchText, placeholder: "Search collections...")
                            .padding(.horizontal, AppConstants.UI.Spacing.large)
                    }
                    
                    if collections.isEmpty {
                        CollectionsEmptyState(showCreateCollection: $showCreateCollection)
                    } else {
                        List {
                            ForEach(filteredCollections) { collection in
                                Button {
                                    selectedCollection = collection
                                } label: {
                                    CollectionsRow(
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
                            }
                            .onDelete(perform: deleteCollections)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.warmGray50)
                        .contentMargins(.bottom, 80, for: .scrollContent)
                    }
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
                CollectionDetailView(collection: collection, showPlusButton: showPlusButton)
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
                            for recording in recordingsInCollection {
                                modelContext.delete(recording)
                            }
                            
                            // Now delete the collection
                            modelContext.delete(collection)
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
    
    private func deleteCollections(offsets: IndexSet) {
        // Get the first collection from offsets and show confirmation
        if let index = offsets.first {
            deletingCollection = filteredCollections[index]
        }
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
