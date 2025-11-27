import SwiftUI

struct SettingsView: View {
    @State private var audioLanguage = "English"
    @State private var selectedModel = "Tiny"
    
    var body: some View {
        NavigationView {
            List {
                // Audio Language Setting
                NavigationLink(destination: AudioLanguageView(selectedLanguage: $audioLanguage)) {
                    HStack(spacing: 16) {
                        Image(systemName: "textformat")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .frame(width: 24)
                        
                        Text("Audio language")
                            .font(.body)
                        
                        Spacer()
                        
                        Text(audioLanguage)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Model Setting
                NavigationLink(destination: ModelSelectionView(selectedModel: $selectedModel)) {
                    HStack(spacing: 16) {
                        Image(systemName: "cpu")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .frame(width: 24)
                        
                        Text("Model")
                            .font(.body)
                        
                        Spacer()
                        
                        Text(selectedModel)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Feedback and Support
                NavigationLink(destination: FeedbackSupportView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .frame(width: 24)
                        
                        Text("Feedback and support")
                            .font(.body)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                // Rate App
                Button(action: {
                    rateApp()
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "star")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .frame(width: 24)
                        
                        Text("Rate app")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Share App
                Button(action: {
                    shareApp()
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .frame(width: 24)
                        
                        Text("Share app")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // Rate app function
    func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
    
    // Share app function
    func shareApp() {
        let appURL = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID")!
        let activityViewController = UIActivityViewController(
            activityItems: ["Check out this app!", appURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

// MARK: - Audio Language Selection View
struct AudioLanguageView: View {
    @Binding var selectedLanguage: String
    @Environment(\.presentationMode) var presentationMode
    
    let languages = ["English", "Spanish", "French", "German", "Italian", "Portuguese", "Chinese", "Japanese", "Korean"]
    
    var body: some View {
        List {
            ForEach(languages, id: \.self) { language in
                Button(action: {
                    selectedLanguage = language
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text(language)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedLanguage == language {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Audio language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Model Selection View
struct ModelSelectionView: View {
    @Binding var selectedModel: String
    @Environment(\.presentationMode) var presentationMode
    
    let models = ["Tiny", "Base", "Small", "Medium", "Large"]
    
    var body: some View {
        List {
            ForEach(models, id: \.self) { model in
                Button(action: {
                    selectedModel = model
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text(model)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedModel == model {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Model")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Feedback and Support View
struct FeedbackSupportView: View {
    var body: some View {
        List {
            Button("Send Feedback") {
                sendFeedback()
            }
            
            Button("Contact Support") {
                contactSupport()
            }
            
            Button("Privacy Policy") {
                openPrivacyPolicy()
            }
            
            Button("Terms of Service") {
                openTermsOfService()
            }
        }
        .navigationTitle("Feedback and support")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func sendFeedback() {
        if let url = URL(string: "mailto:support@yourapp.com?subject=Feedback") {
            UIApplication.shared.open(url)
        }
    }
    
    func contactSupport() {
        if let url = URL(string: "mailto:support@yourapp.com?subject=Support Request") {
            UIApplication.shared.open(url)
        }
    }
    
    func openPrivacyPolicy() {
        if let url = URL(string: "https://yourapp.com/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    func openTermsOfService() {
        if let url = URL(string: "https://yourapp.com/terms") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
