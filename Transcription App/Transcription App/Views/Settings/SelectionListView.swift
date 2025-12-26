import SwiftUI

struct SelectionItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String?  // Optional description text
    let emoji: String?  // Optional emoji

    init(title: String, description: String? = nil, emoji: String? = nil) {
        self.title = title
        self.description = description
        self.emoji = emoji
    }
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
            return items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                (item.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            CustomTopBar(
                title: title,
                leftIcon: "caret-left",
                onLeftTap: { dismiss() }
            )
            
            if showSearchBar {
                SearchBar(text: $searchText, placeholder: "Search languages...")
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
            
            List {
                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 0) {
                        Button(action: {
                            selectedItem = item.title
                            dismiss()
                        }) {
                            HStack(spacing: 0) {
                                if let emoji = item.emoji {
                                    Text(emoji)
                                        .font(.system(size: 24))
                                        .padding(.trailing, 16)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(item.title)
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)

                                    if let description = item.description {
                                        Text(description)
                                            .font(.dmSansMedium(size: 14))
                                            .foregroundColor(.blueGray400)
                                    }
                                }

                                Spacer()

                                if selectedItem == item.title {
                                    Image("check-bold")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.accent)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < filteredItems.count - 1 {
                            HStack(spacing: 0) {
                                Spacer()
                                    .frame(width: 60) // 20 (padding) + 24 (emoji) + 16 (spacing)

                                Rectangle()
                                    .fill(Color.blueGray200)
                                    .frame(height: 1)
                            }
                            .padding(.trailing, 20)
                        }
                    }
                    .listRowBackground(Color.white)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color.white.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()

    }
}


