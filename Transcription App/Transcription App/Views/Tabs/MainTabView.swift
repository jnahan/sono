import SwiftUI
import SwiftData

private struct ShowPlusButtonKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(true)
}

extension EnvironmentValues {
    var showPlusButton: Binding<Bool> {
        get { self[ShowPlusButtonKey.self] }
        set { self[ShowPlusButtonKey.self] = newValue }
    }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [Folder]
    
    @State private var selectedTab = 0
    @State private var showPlusButton = true
    
    @State private var showAddSheet = false
    @State private var showRecorderScreen = false
    @State private var showFilePicker = false
    @State private var showPhotoPicker = false
    @State private var showTranscriptionDetail = false
    @State private var pendingAudioURL: URL?
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                RecordingsView()
                    .environment(\.showPlusButton, $showPlusButton)
                    .tabItem { EmptyView() } // Hide default tab item
                    .tag(0)
                
                FoldersView()
                    .environment(\.showPlusButton, $showPlusButton)
                    .tabItem { EmptyView() } // Hide default tab item
                    .tag(1)
            }
            
            // Custom Tab Bar Overlay - Only show when on main tabs
            if showPlusButton {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 40) {
                        // Home button
                        Button {
                            selectedTab = 0
                        } label: {
                            Image(selectedTab == 0 ? "house-fill" : "house")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(selectedTab == 0 ? .baseBlack : .warmGray400)
                                .frame(width: 32, height: 32)
                        }
                        
                        // Plus button
                        Button {
                            showAddSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 120, height: 48)
                            .background(Color.baseBlack)
                            .cornerRadius(24)
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        }
                        
                        // Folder button
                        Button {
                            selectedTab = 1
                        } label: {
                            Image(selectedTab == 1 ? "folder-fill" : "folder")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(selectedTab == 1 ? .baseBlack : .warmGray400)
                                .frame(width: 32, height: 32)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            // Hide the default tab bar
            let appearance = UITabBar.appearance()
            appearance.isHidden = true
        }
        .fullScreenCover(isPresented: $showAddSheet) {
            NewRecordingSheet(
                onRecordAudio: { showRecorderScreen = true },
                onUploadFile: { showFilePicker = true },
                onChooseFromPhotos: { showPhotoPicker = true }
            )
            .presentationDetents([.height(240)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $showRecorderScreen) {
            RecorderView()
        }
        .sheet(isPresented: $showFilePicker) {
            MediaFilePicker(
                onFilePicked: { url, mediaType in
                    pendingAudioURL = url
                    showFilePicker = false
                    showTranscriptionDetail = true
                },
                onCancel: {
                    showFilePicker = false
                }
            )
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoVideoPicker(
                onMediaPicked: { url in
                    pendingAudioURL = url
                    showPhotoPicker = false
                    showTranscriptionDetail = true
                },
                onCancel: {
                    showPhotoPicker = false
                }
            )
        }
        .fullScreenCover(item: Binding(
            get: { showTranscriptionDetail ? pendingAudioURL : nil },
            set: { newValue in
                if newValue == nil {
                    showTranscriptionDetail = false
                    pendingAudioURL = nil
                }
            }
        )) { audioURL in
            CreateRecordingView(
                isPresented: $showTranscriptionDetail,
                audioURL: audioURL,
                folders: folders,
                modelContext: modelContext,
                onTranscriptionComplete: {
                    pendingAudioURL = nil
                    showTranscriptionDetail = false
                }
            )
        }
    }
}
