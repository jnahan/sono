import SwiftUI

struct SelectionItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String?  // Optional description text
}

struct SelectionListView: View {
    let title: String
    let items: [SelectionItem]
    @Binding var selectedItem: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.showPlusButton) private var showPlusButton
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
            .onAppear {
                // Hide tab bar immediately when top bar appears
                showPlusButton.wrappedValue = false
            }
            
            if showSearchBar {
                SearchBar(text: $searchText, placeholder: "Search languages...")
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
            
            List {
                ForEach(filteredItems) { item in
                    Button(action: {
                        selectedItem = item.title
                        dismiss()
                    }) {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title)
                                    .font(.system(size: 16))
                                    .foregroundColor(.baseBlack)
                                
                                if let description = item.description {
                                    Text(description)
                                        .font(.dmSansMedium(size: 14))
                                        .foregroundColor(.warmGray400)
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
                    .listRowBackground(Color.warmGray50)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color.warmGray50.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .onAppear {
            showPlusButton.wrappedValue = false
        }
        .task {
            showPlusButton.wrappedValue = false
        }
    }
}


