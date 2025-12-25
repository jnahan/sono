import SwiftUI
import SwiftData

struct CollectionPickerSheet: View {
    let collections: [Collection]
    @Binding var selectedCollections: Set<Collection>
    let modelContext: ModelContext
    @Binding var isPresented: Bool
    
    // Mass move support
    let recordings: [Recording]? // If provided, this is a mass move operation
    let onMassMoveComplete: (() -> Void)? // Callback after mass move
    
    @State private var showCreateCollection = false
    @State private var newCollectionName = ""

    // Computed property to determine which collections should show checkmarks
    private var collectionsWithCheckmarks: Set<UUID> {
        if let recordings = recordings {
            // For mass actions: show checkmark if ALL selected recordings are in this collection
            guard !recordings.isEmpty else { return Set() }

            // Get the intersection of all recording collections
            var commonCollections = Set(recordings.first!.collections.map { $0.id })
            for recording in recordings.dropFirst() {
                let recordingCollections = Set(recording.collections.map { $0.id })
                commonCollections.formIntersection(recordingCollections)
            }
            return commonCollections
        } else {
            // For single selection: show checkmarks for selected collections
            return Set(selectedCollections.map { $0.id })
        }
    }

    init(
        collections: [Collection],
        selectedCollections: Binding<Set<Collection>>,
        modelContext: ModelContext,
        isPresented: Binding<Bool>,
        recordings: [Recording]? = nil,
        onMassMoveComplete: (() -> Void)? = nil
    ) {
        self.collections = collections
        self._selectedCollections = selectedCollections
        self.modelContext = modelContext
        self._isPresented = isPresented
        self.recordings = recordings
        self.onMassMoveComplete = onMassMoveComplete
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            CustomTopBar(
                title: "Select collections",
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
                                        .stroke(Color.blueGray200, lineWidth: 1)
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Existing collections
                ForEach(collections) { collection in
                    Button {
                        if recordings != nil {
                            // Mass move: toggle collection for all recordings
                            handleMassToggle(collection)
                        } else {
                            // Multi-select: toggle collection in set
                            if selectedCollections.contains(where: { $0.id == collection.id }) {
                                selectedCollections.remove(collection)
                            } else {
                                selectedCollections.insert(collection)
                            }
                            // Auto-close after selection
                            isPresented = false
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

                            if collectionsWithCheckmarks.contains(collection.id) {
                                Image("check-bold")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.accent)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
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
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.top, 8)
        .background(Color.baseWhite)
        .presentationDetents([.height(calculateHeight())])
        .presentationCompactAdaptation(.none)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.baseWhite)
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
                                    // Mass move: add to newly created collection
                                    handleMassToggle(newCollection)
                                } else {
                                    // Multi-select: add the new collection
                                    selectedCollections.insert(newCollection)
                                    // Auto-close after creating and selecting new collection
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
    
    private func handleMassToggle(_ collection: Collection) {
        guard let recordings = recordings else { return }

        Task { @MainActor in
            // Check if all recordings are already in this collection
            let allInCollection = collectionsWithCheckmarks.contains(collection.id)

            for recording in recordings {
                if allInCollection {
                    // Remove from this collection
                    recording.collections.removeAll(where: { $0.id == collection.id })
                } else {
                    // Add to this collection if not already present
                    if !recording.collections.contains(where: { $0.id == collection.id }) {
                        recording.collections.append(collection)
                    }
                }
            }

            do {
                try modelContext.save()
                // Auto-close after selection
                isPresented = false
            } catch {
                Logger.error("CollectionPicker", "Failed to toggle collection: \(error.localizedDescription)")
            }
        }
    }
    
    private func calculateHeight() -> CGFloat {
        let baseHeight: CGFloat = 280
        let rowHeight: CGFloat = 64
        let additionalRows = collections.count

        return baseHeight + (CGFloat(additionalRows) * rowHeight)
    }
}



