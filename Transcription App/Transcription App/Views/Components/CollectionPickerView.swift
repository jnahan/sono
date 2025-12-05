import SwiftUI
import SwiftData

struct CollectionPickerView: View {
    let collections: [Collection]
    @Binding var selectedCollection: Collection?
    let modelContext: ModelContext
    @Binding var isPresented: Bool
    
    @State private var showCreateCollection = false
    @State private var newCollectionName = ""
    
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
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.baseBlack)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                
                // Existing collections
                ForEach(collections) { collection in
                    Button {
                        // Toggle: if clicking the same collection, deselect it
                        if selectedCollection?.id == collection.id {
                            selectedCollection = nil
                        } else {
                            selectedCollection = collection
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
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.baseBlack)
                            
                            Spacer()
                            
                            if selectedCollection?.id == collection.id {
                                Image("check")
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
                        selectedCollection = newCollection
                        newCollectionName = ""
                    }
                },
                existingCollections: collections,
                currentCollection: nil
            )
        }
    }
    
    private func calculateHeight() -> CGFloat {
        let baseHeight: CGFloat = 179
        let rowHeight: CGFloat = 64
        let numberOfRows = CGFloat(collections.count + 1)
        let contentHeight = baseHeight + (rowHeight * numberOfRows)
        
        return min(contentHeight, 480)
    }
}
