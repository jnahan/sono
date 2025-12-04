import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var audioLanguage = "English"
    @State private var selectedModel = "Tiny"
    
    // Data for selection lists
    private let audioLanguages = [
        SelectionItem(emoji: nil, title: "English"),
        SelectionItem(emoji: nil, title: "Spanish"),
        SelectionItem(emoji: nil, title: "French"),
        SelectionItem(emoji: nil, title: "German"),
        SelectionItem(emoji: nil, title: "Italian"),
        SelectionItem(emoji: nil, title: "Portuguese"),
        SelectionItem(emoji: nil, title: "Chinese"),
        SelectionItem(emoji: nil, title: "Japanese"),
        SelectionItem(emoji: nil, title: "Korean")
    ]
    
    private let models = [
        SelectionItem(emoji: "✨", title: "Tiny"),
        SelectionItem(emoji: "✨", title: "Base"),
        SelectionItem(emoji: "✨", title: "Small"),
        SelectionItem(emoji: "✨", title: "Medium"),
        SelectionItem(emoji: "✨", title: "Large")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.warmGray100
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    CustomTopBar(
                        title: "Settings",
                        leftIcon: "caret-left",
                        onLeftTap: { dismiss() }
                    )
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // Top Section: Audio Language & Model
                            VStack(spacing: 0) {
                                NavigationLink(destination: SelectionListView(
                                    title: "Audio Language",
                                    items: audioLanguages,
                                    selectedItem: $audioLanguage
                                )) {
                                    SettingsRow(title: "Audio language", value: audioLanguage, imageName: "text-aa")
                                }
                                
                                Divider().padding(.leading, 60)
                                
                                NavigationLink(destination: SelectionListView(
                                    title: "Model",
                                    items: models,
                                    selectedItem: $selectedModel
                                )) {
                                    SettingsRow(title: "Model", value: selectedModel, imageName: "sparkle")
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            
                            // Bottom Section: Feedback, Rate, Share
                            VStack(spacing: 0) {
                                Button(action: sendFeedback) {
                                    SettingsRow(title: "Feedback and support", value: nil, imageName: "seal-question")
                                }
                                
                                Divider().padding(.leading, 60)
                                
                                Button(action: rateApp) {
                                    SettingsRow(title: "Rate app", value: nil, imageName: "star")
                                }
                                
                                Divider().padding(.leading, 60)
                                
                                Button(action: shareApp) {
                                    SettingsRow(title: "Share app", value: nil, imageName: "export")
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // Footer
                    VStack(spacing: 8) {
                        Image("diamond")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        
                        Text("SONO")
                            .font(.custom("LibreBaskerville-Regular", size: 20))
                            .foregroundColor(.baseBlack)
                        
                        Text("Made with love")
                            .font(.system(size: 16))
                            .foregroundColor(.warmGray600)
                        
                        Text("Version 1.0.0")
                            .font(.system(size: 14))
                            .foregroundColor(.warmGray400)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .tabBar)
        }
        .presentationDragIndicator(.hidden)
    }
    
    // MARK: - Functions
    func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
    
    func shareApp() {
        let appURL = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID")!
        let activityVC = UIActivityViewController(
            activityItems: ["Check out this app!", appURL],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    func sendFeedback() {
        if let url = URL(string: "mailto:support@yourapp.com?subject=Feedback") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let title: String
    let value: String?
    let imageName: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(.black)
            
            Text(title)
                .font(.system(size: 17))
                .foregroundColor(.baseBlack)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.system(size: 17))
                    .foregroundColor(.warmGray500)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.warmGray400)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
