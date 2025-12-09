import SwiftUI
import SwiftData

struct CollectionPickerSheet: View {
    let collections: [Collection]
    @Binding var selectedCollection: Collection?
    let modelContext: ModelContext
    @Binding var isPresented: Bool
    
    // Mass move support
    let recordings: [Recording]? // If provided, this is a mass move operation
    let onMassMoveComplete: (() -> Void)? // Callback after mass move
    let showRemoveFromCollection: Bool // Whether to show "Remove from collection" option
    
    @State private var showCreateCollection = false
    @State private var newCollectionName = ""
    
    init(
        collections: [Collection],
        selectedCollection: Binding<Collection?>,
        modelContext: ModelContext,
        isPresented: Binding<Bool>,
        recordings: [Recording]? = nil,
        onMassMoveComplete: (() -> Void)? = nil,
        showRemoveFromCollection: Bool = false
    ) {
        self.collections = collections
        self._selectedCollection = selectedCollection
        self.modelContext = modelContext
        self._isPresented = isPresented
        self.recordings = recordings
        self.onMassMoveComplete = onMassMoveComplete
        self.showRemoveFromCollection = showRemoveFromCollection
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.warmGray300)
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Title
            Text("Choose a collection")
                .font(.custom("LibreBaskerville-Regular", size: 24))
                .foregroundColor(.baseBlack)
                .padding(.bottom, 32)
            
            // Collections list
            VStack(spacing: 0) {
                // Create collection button
                Button {
                    showCreateCollection = true
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.accentLight)
                                .frame(width: 40, height: 40)
                            
                            Image("folder-plus")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.accent)
                        }
                        
                        Text("Create collection")
                            .font(.interMedium(size: 16))
                            .foregroundColor(.baseBlack)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                
                // Remove from collection option (only for mass move in collection detail view)
                if recordings != nil && showRemoveFromCollection {
                    Button {
                        handleSelection(nil)
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.warmGray200)
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "folder.badge.minus")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.warmGray600)
                            }
                            
                            Text("Remove from collection")
                                .font(.interMedium(size: 16))
                                .foregroundColor(.baseBlack)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                
                // Existing collections
                ForEach(collections) { collection in
                    Button {
                        if recordings != nil {
                            // Mass move: move immediately
                            handleSelection(collection)
                        } else {
                            // Single selection: toggle
                            if selectedCollection?.id == collection.id {
                                selectedCollection = nil
                            } else {
                                selectedCollection = collection
                                // Automatically close the modal when a collection is selected
                                isPresented = false
                            }
                        }
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentLight)
                                    .frame(width: 40, height: 40)
                                
                                Image("waveform")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.accent)
                            }
                            
                            Text(collection.name)
                                .font(.interMedium(size: 16))
                                .foregroundColor(.baseBlack)
                            
                            Spacer()
                            
                            if selectedCollection?.id == collection.id {
                                Image("check-bold")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.accent)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxHeight: 200)
            
            Spacer()
            
            // Done button
            Button {
                isPresented = false
            } label: {
                Text("Done")
            }
            .buttonStyle(AppButtonStyle())
        }
        .frame(maxHeight: 480)
        .background(Color.warmGray50)
        .presentationDetents([.height(calculateHeight())])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showCreateCollection) {
            CollectionFormSheet(
                isPresented: $showCreateCollection,
                collectionName: $newCollectionName,
                isEditing: false,
                onSave: {
                    if !newCollectionName.isEmpty {
                        let newCollection = Collection(name: newCollectionName)
                        modelContext.insert(newCollection)
                        newCollectionName = ""
                        
                        // Save new collection asynchronously
                        Task { @MainActor in
                            do {
                                try modelContext.save()
                                
                                if recordings != nil {
                                    // Mass move: move to newly created collection
                                    handleSelection(newCollection)
                                } else {
                                    // Single selection: select the new collection
                                    selectedCollection = newCollection
                                    isPresented = false
                                }
                            } catch {
                                Logger.error("CollectionPicker", "Failed to save new collection: \(error.localizedDescription)")
                            }
                        }
                    }
                },
                existingCollections: collections,
                currentCollection: nil
            )
        }
    }
    
    private var titleText: String {
        if let recordings = recordings, recordings.count > 0 {
            return "Move \(recordings.count) recording\(recordings.count == 1 ? "" : "s")"
        }
        return "Choose a collection"
    }
    
    private func handleSelection(_ collection: Collection?) {
        if let recordings = recordings {
            // Mass move operation - perform asynchronously to avoid blocking main thread
            Task { @MainActor in
                for recording in recordings {
                    recording.collection = collection
                }
                
                do {
                    try modelContext.save()
                    isPresented = false
                    onMassMoveComplete?()
                } catch {
                    Logger.error("CollectionPicker", "Failed to move recordings: \(error.localizedDescription)")
                }
            }
        } else {
            // Single selection - handled in button action
            selectedCollection = collection
            isPresented = false
        }
    }
    
    private func calculateHeight() -> CGFloat {
        let baseHeight: CGFloat = 179
        let rowHeight: CGFloat = 64
        let extraRows = recordings != nil ? 1 : 0 // Add row for "Remove from collection" if mass move
        let numberOfRows = CGFloat(collections.count + 1 + extraRows)
        let contentHeight = baseHeight + (rowHeight * numberOfRows)
        
        return min(contentHeight, 500)
    }
}



