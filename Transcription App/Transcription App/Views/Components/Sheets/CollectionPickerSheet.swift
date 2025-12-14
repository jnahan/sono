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
            DragHandle()
                .padding(.bottom, 8) // Has top bar, so 8px spacing
            
            // Top bar
            CustomTopBar(
                title: "Add to collection",
                leftIcon: "x",
                onLeftTap: {
                    isPresented = false
                }
            )

            // Collections list
            VStack(spacing: 0) {
                // Create collection button
                Button {
                    showCreateCollection = true
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.warmGray200, lineWidth: 1)
                                )

                            Image("folder")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.accent)
                        }

                        Text("Create collection")
                            .font(.dmSansSemiBold(size: 16))
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

                                Image("folder-minus")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.warmGray600)
                            }

                            Text("Remove from collection")
                                .font(.dmSansMedium(size: 16))
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
                                    .fill(Color.accent)
                                    .frame(width: 40, height: 40)

                                Image("waveform")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.accentLight)
                            }

                            Text(collection.name)
                                .font(.dmSansSemiBold(size: 16))
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
            .padding(.top, 16)

            Spacer()
                .frame(height: 24)

            // Done button
            Button {
                isPresented = false
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppButtonStyle())
        }
        .background(Color.warmGray50)
        .presentationDetents([.height(calculateHeight())])
        .presentationCompactAdaptation(.none)
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.warmGray50)
        .presentationCornerRadius(16)
        .interactiveDismissDisabled(false)
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
        let baseHeight: CGFloat = 280
        let rowHeight: CGFloat = 64

        var additionalRows = collections.count
        if recordings != nil && showRemoveFromCollection {
            additionalRows += 1 // Add row for "Remove from collection"
        }

        return baseHeight + (CGFloat(additionalRows) * rowHeight)
    }
}



