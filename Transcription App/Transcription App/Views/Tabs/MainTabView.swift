import SwiftUI
import SwiftData

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
                    .tabItem {
                        Image(selectedTab == 0 ? "house-fill" : "house")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(selectedTab == 0 ? .baseBlack : .warmGray400)
                            .frame(width: 32, height: 32)
                    }
                    .tag(0)
                
                FoldersView()
                    .environment(\.showPlusButton, $showPlusButton)
                    .tabItem {
                        Image(selectedTab == 1 ? "folder-fill" : "folder")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(selectedTab == 1 ? .baseBlack : .warmGray400)
                            .frame(width: 32, height: 32)
                    }
                    .tag(1)
            }
            .onChange(of: selectedTab) { _, newTab in
                showPlusButton = true
            }
            
            if showPlusButton {
                VStack {
                    Spacer()
                    
                    Button {
                        showAddSheet = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.baseBlack)
                                .frame(width: 56, height: 56)
                                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.baseWhite)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showAddSheet) {
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

private struct ShowPlusButtonKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(true)
}

extension EnvironmentValues {
    var showPlusButton: Binding<Bool> {
        get { self[ShowPlusButtonKey.self] }
        set { self[ShowPlusButtonKey.self] = newValue }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Folder.self], inMemory: true)
}
