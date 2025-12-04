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
    @Query private var collections: [Collection]

    
    @State private var selectedTab = 0
    @State private var showPlusButton = true
    
    @State private var showNewRecordingSheet = false
    @State private var showRecorderScreen = false
    @State private var showFilePicker = false
    @State private var showVideoPicker = false
    // used to pass file url from picker to transcription screen
    @State private var pendingAudioURL: URL?
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                RecordingsView()
                    .environment(\.showPlusButton, $showPlusButton)
                    .tabItem { EmptyView() } // Hide default tab item
                    .tag(0)
                
                CollectionsView()
                    .environment(\.showPlusButton, $showPlusButton)
                    .tabItem { EmptyView() } // Hide default tab item
                    .tag(1)
            }
            
            // Custom Tab Bar
            if showPlusButton {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
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
                                showNewRecordingSheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 120, height: 48)
                                .background(Color.baseBlack)
                                .cornerRadius(32)
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
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(
                            Color.warmGray50
                                .ignoresSafeArea(edges: .bottom)
                        )
                    }
                }
            }
        }
        .onAppear {
            // Hide the default tab bar and remove borders
            let appearance = UITabBar.appearance()
            appearance.isHidden = true
            appearance.backgroundImage = UIImage()
            appearance.shadowImage = UIImage()
            appearance.backgroundColor = .clear
        }
        .fullScreenCover(isPresented: $showNewRecordingSheet) {
            NewRecordingSheet(
                onRecordAudio: { showRecorderScreen = true },
                onUploadFile: { showFilePicker = true },
                onChooseFromPhotos: { showVideoPicker = true }
            )
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $showRecorderScreen) {
            RecorderView()
        }
        // handle file picker, video picker logic
        .sheet(isPresented: $showFilePicker) {
            MediaFilePicker(
                onFilePicked: { url, mediaType in
                    pendingAudioURL = url
                    showFilePicker = false
                },
                onCancel: {
                    showFilePicker = false
                }
            )
        }
        .sheet(isPresented: $showVideoPicker) {
            PhotoVideoPicker(
                onMediaPicked: { url in
                    pendingAudioURL = url
                    showVideoPicker = false
                },
                onCancel: {
                    showVideoPicker = false
                }
            )
        }
        .fullScreenCover(item: $pendingAudioURL) { audioURL in
            RecordingFormView(
                isPresented: Binding(
                    get: { pendingAudioURL != nil },
                    set: { if !$0 { pendingAudioURL = nil } }
                ),
                audioURL: audioURL,
                existingRecording: nil,
                collections: collections,
                modelContext: modelContext,
                onTranscriptionComplete: {
                    pendingAudioURL = nil
                },
                onExit: {
                    pendingAudioURL = nil
                    selectedTab = 0  // Go back to recordings home tab
                }
            )
        }    }
}
