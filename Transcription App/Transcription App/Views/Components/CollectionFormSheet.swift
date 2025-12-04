import SwiftUI
import SwiftData

struct CollectionFormSheet: View {
    @Binding var isPresented: Bool
    @Binding var folderName: String
    let isEditing: Bool
    let onSave: () -> Void
    let existingFolders: [Folder]
    let currentFolder: Folder?
    
    @FocusState private var isTextFieldFocused: Bool
    
    @State private var folderNameError: String? = nil
    
    // Validation constants
    private let maxFolderNameLength = 50
    
    private var isFormValid: Bool {
        validateFolderName()
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
            Text(isEditing ? "Rename folder" : "Create folder")
                .font(.custom("LibreBaskerville-Regular", size: 24))
                .foregroundColor(.baseBlack)
                .padding(.bottom, 32)
            
            // Text field
            VStack(alignment: .leading, spacing: 8) {
                InputLabel(text: "Folder name")
                    .padding(.horizontal, 24)
                
                InputField(
                    text: $folderName,
                    placeholder: "Folder name",
                    error: folderNameError
                )
                .padding(.horizontal, 24)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    if isFormValid {
                        onSave()
                        isPresented = false
                    }
                }
                .onChange(of: folderName) { oldValue, newValue in
                    validateFolderNameWithError()
                }
            }
            .padding(.bottom, 32)
            
            // Save button
            Button {
                if isFormValid {
                    onSave()
                    isPresented = false
                }
            } label: {
                Text(isEditing ? "Save changes" : "Create folder")
            }
            .disabled(!isFormValid)
            .buttonStyle(AppButtonStyle())
        }
        .background(Color.warmGray100)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.warmGray100)
        .presentationCornerRadius(24)
        .onAppear {
            #if !os(macOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
            #endif
            validateFolderNameWithError()
        }
    }
    
    // MARK: - Validation Functions
    
    private func validateFolderName() -> Bool {
        if folderName.isEmpty {
            return false
        }
        
        if folderName.count > maxFolderNameLength {
            return false
        }
        
        // Check for duplicates (exclude current folder if editing)
        let isDuplicate = existingFolders.contains { folder in
            // If editing, ignore the current folder
            if isEditing, let currentFolder = currentFolder, folder.id == currentFolder.id {
                return false
            }
            return folder.name.lowercased() == folderName.lowercased()
        }
        
        return !isDuplicate
    }
    
    @discardableResult
    private func validateFolderNameWithError() -> Bool {
        if folderName.isEmpty {
            folderNameError = "Folder name is required"
            return false
        } else if folderName.count > maxFolderNameLength {
            folderNameError = "Folder name must be less than \(maxFolderNameLength) characters"
            return false
        } else {
            // Check for duplicates (exclude current folder if editing)
            let isDuplicate = existingFolders.contains { folder in
                // If editing, ignore the current folder
                if isEditing, let currentFolder = currentFolder, folder.id == currentFolder.id {
                    return false
                }
                return folder.name.lowercased() == folderName.lowercased()
            }
            
            if isDuplicate {
                folderNameError = "A folder with this name already exists"
                return false
            } else {
                folderNameError = nil
                return true
            }
        }
    }
}
