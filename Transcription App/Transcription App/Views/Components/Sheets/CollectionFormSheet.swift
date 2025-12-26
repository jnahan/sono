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

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            CustomTopBar(
                title: isEditing ? "Rename collection" : "New collection",
                leftIcon: "x",
                onLeftTap: {
                    isPresented = false
                }
            )

            // Text field
            VStack(alignment: .leading, spacing: 6) {
                InputLabel(text: "Collection name")
                    .padding(.horizontal, 24)

                InputField(
                    text: $collectionName,
                    placeholder: "Collection name"
                )
                .padding(.horizontal, 24)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    onSave()
                    isPresented = false
                }
            }
            .padding(.top, 16)

            Spacer()
                .frame(height: 24)

            // Save button
            Button {
                onSave()
                isPresented = false
            } label: {
                Text(isEditing ? "Save changes" : "Create collection")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.top, 8)
        .background(Color.white)
        .compactSheetStyle(height: 280)
        .onAppear {
            #if !os(macOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
            #endif
        }
    }
}
