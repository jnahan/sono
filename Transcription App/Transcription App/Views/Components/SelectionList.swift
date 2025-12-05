import SwiftUI

struct SelectionItem: Identifiable {
    let id = UUID()
    let emoji: String?   // Optional emoji
    let title: String
}

struct SelectionListView: View {
    let title: String
    let items: [SelectionItem]
    @Binding var selectedItem: String
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    // Show search bar only for language selection (has many items)
    private var showSearchBar: Bool {
        title == "Audio Language"
    }
    
    // Filter items based on search text
    private var filteredItems: [SelectionItem] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            CustomTopBar(
                title: title,
                leftIcon: "caret-left",
                onLeftTap: { dismiss() }
            )
            .padding(.top, 12)
            
            if showSearchBar {
                SearchBar(text: $searchText, placeholder: "Search languages...")
                    .padding(.horizontal, AppConstants.UI.Spacing.large)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
            
            List {
                ForEach(filteredItems) { item in
                    Button(action: {
                        selectedItem = item.title
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            if let emoji = item.emoji {
                                Text(emoji)
                                    .font(.system(size: 24))
                            }
                            
                            Text(item.title)
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            if selectedItem == item.title {
                                Image("check")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.accent)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.warmGray50)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparatorTint(Color.warmGray300)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.warmGray50)
        }
        .background(Color.warmGray50)
        .navigationBarHidden(true)
    }
}
