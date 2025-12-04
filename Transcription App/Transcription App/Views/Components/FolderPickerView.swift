import SwiftUI
import SwiftData

struct FolderPickerView: View {
    let folders: [Folder]
    @Binding var selectedFolder: Folder?
    let modelContext: ModelContext
    @Binding var isPresented: Bool
    
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.warmGray300)
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Title
            Text("Choose a folder")
                .font(.custom("LibreBaskerville-Regular", size: 24))
                .foregroundColor(.baseBlack)
                .padding(.bottom, 32)
            
            // Folders list
            VStack(spacing: 0) {
                // Create folder button
                Button {
                    showCreateFolder = true
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
                        
                        Text("Create folder")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.baseBlack)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                
                // Existing folders
                ForEach(folders) { folder in
                    Button {
                        // Toggle: if clicking the same folder, deselect it
                        if selectedFolder?.id == folder.id {
                            selectedFolder = nil
                        } else {
                            selectedFolder = folder
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
                            
                            Text(folder.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.baseBlack)
                            
                            Spacer()
                            
                            if selectedFolder?.id == folder.id {
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
        .sheet(isPresented: $showCreateFolder) {
            CollectionFormSheet(
                isPresented: $showCreateFolder,
                folderName: $newFolderName,
                isEditing: false,
                onSave: {
                    if !newFolderName.isEmpty {
                        let newFolder = Folder(name: newFolderName)
                        modelContext.insert(newFolder)
                        selectedFolder = newFolder
                        newFolderName = ""
                    }
                },
                existingFolders: folders,
                currentFolder: nil
            )
        }
    }
    
    private func calculateHeight() -> CGFloat {
        let baseHeight: CGFloat = 179
        let rowHeight: CGFloat = 64
        let numberOfRows = CGFloat(folders.count + 1)
        let contentHeight = baseHeight + (rowHeight * numberOfRows)
        
        return min(contentHeight, 480)
    }
}
