import SwiftUI
import SwiftData

struct CollectionFormSheet: View {
    @Binding var isPresented: Bool
    @Binding var collectionName: String
    let isEditing: Bool
    let onSave: () -> Void
    let existingCollections: [Collection]
    let currentCollection: Collection?
    
    @FocusState private var isTextFieldFocused: Bool
    
    @State private var collectionNameError: String? = nil
    @State private var hasAttemptedSubmit = false
    
    private var isFormValid: Bool {
        validateCollectionName()
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
            Text(isEditing ? "Rename collection" : "Create collection")
                .font(.custom("DMSans-Medium", size: 24))
                .foregroundColor(.baseBlack)
                .padding(.bottom, 32)
            
            // Text field
            VStack(alignment: .leading, spacing: 8) {
                InputLabel(text: "Collection name")
                    .padding(.horizontal, 24)
                
                InputField(
                    text: $collectionName,
                    placeholder: "Collection name",
                    error: collectionNameError
                )
                .padding(.horizontal, 24)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    hasAttemptedSubmit = true
                    validateCollectionNameWithError()
                    if isFormValid {
                        onSave()
                        isPresented = false
                    }
                }
            }
            .padding(.bottom, 32)
            
            // Save button
            Button {
                hasAttemptedSubmit = true
                validateCollectionNameWithError()
                if isFormValid {
                    onSave()
                    isPresented = false
                }
            } label: {
                Text(isEditing ? "Save changes" : "Create collection")
            }
            .buttonStyle(AppButtonStyle())
        }
        .background(Color.warmGray50)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.warmGray50)
        .presentationCornerRadius(24)
        .onAppear {
            #if !os(macOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
            #endif
        }
    }
    
    // MARK: - Validation Functions
    
    private func validateCollectionName() -> Bool {
        let trimmed = collectionName.trimmed
        
        if trimmed.isEmpty {
            return false
        }
        
        if trimmed.count > AppConstants.Validation.maxCollectionNameLength {
            return false
        }
        
        // Get existing names, excluding current collection if editing
        let existingNames = existingCollections.compactMap { collection -> String? in
            if isEditing, let currentCollection = currentCollection, collection.id == currentCollection.id {
                return nil
            }
            return collection.name
        }
        
        return ValidationHelper.validateUnique(trimmed, against: existingNames, fieldName: "collection") == nil
    }
    
    @discardableResult
    private func validateCollectionNameWithError() -> Bool {
        if hasAttemptedSubmit {
            let trimmed = collectionName.trimmed
            
            // Validate not empty
            if let error = ValidationHelper.validateNotEmpty(trimmed, fieldName: "Collection name") {
                collectionNameError = error
                return false
            }
            
            // Validate length
            if let error = ValidationHelper.validateLength(trimmed, max: AppConstants.Validation.maxCollectionNameLength, fieldName: "Collection name") {
                collectionNameError = error
                return false
            }
            
            // Get existing names, excluding current collection if editing
            let existingNames = existingCollections.compactMap { collection -> String? in
                if isEditing, let currentCollection = currentCollection, collection.id == currentCollection.id {
                    return nil
                }
                return collection.name
            }
            
            // Validate uniqueness
            if let error = ValidationHelper.validateUnique(trimmed, against: existingNames, fieldName: "collection") {
                collectionNameError = error
                return false
            }
            
            collectionNameError = nil
            return true
        } else {
            // Don't show errors until submit is attempted
            collectionNameError = nil
            return validateCollectionName()
        }
    }
}
