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
    @Query(sort: \Collection.name) private var collections: [Collection]


    @State private var selectedTab = 0
    @State private var showPlusButton = true
    @ObservedObject private var actionSheetManager = ActionSheetManager.shared

    @State private var showNewRecordingSheet = false
    @State private var showRecorderScreen = false
    @State private var showFilePicker = false
    @State private var showVideoPicker = false
    // used to pass file url from picker to transcription screen
    @State private var pendingAudioURL: URL?
    @State private var isExtractingAudio = false
    @State private var showExtractionError = false
    @State private var extractionErrorMessage = ""
    
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
            VStack {
                Spacer()
                
                if showPlusButton {
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
                                    Image("plus-bold")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
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
            
            // ActionSheet overlay - must be on top
            if showNewRecordingSheet {
                NewRecordingSheet(
                    onRecordAudio: { showRecorderScreen = true },
                    onUploadFile: { showFilePicker = true },
                    onChooseFromPhotos: { showVideoPicker = true },
                    isPresented: $showNewRecordingSheet
                )
                .zIndex(1000)
            }

            // Dots three action sheet
            if actionSheetManager.isPresented {
                DotsThreeSheet(
                    isPresented: $actionSheetManager.isPresented,
                    actions: actionSheetManager.actions
                )
                .zIndex(1000)
            }

        }
        .overlay(alignment: .top) {
            if showExtractionError {
                ErrorToastView(
                    message: extractionErrorMessage,
                    isPresented: $showExtractionError
                )
                .padding(.top, 8)
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
        .fullScreenCover(isPresented: $showRecorderScreen) {
            RecorderView(onDismiss: {
                showRecorderScreen = false
            })
        }
        // handle file picker, video picker logic
        .sheet(isPresented: $showFilePicker) {
            MediaFilePicker(
                onFilePicked: { url, mediaType in
                    showFilePicker = false

                    // If it's a video file, extract audio first
                    if mediaType == .video {
                        Task {
                            isExtractingAudio = true
                            do {
                                let audioURL = try await AudioExtractor.extractAudio(from: url)

                                // Delete the temp video file after extraction
                                try? FileManager.default.removeItem(at: url)

                                await MainActor.run {
                                    isExtractingAudio = false
                                    pendingAudioURL = audioURL
                                }
                            } catch {
                                // Clean up temp video file even on error
                                try? FileManager.default.removeItem(at: url)

                                await MainActor.run {
                                    isExtractingAudio = false
                                    extractionErrorMessage = error.localizedDescription
                                    showExtractionError = true
                                }
                            }
                        }
                    } else {
                        // Audio file - use directly
                        pendingAudioURL = url
                    }
                },
                onCancel: {
                    showFilePicker = false
                }
            )
        }
        .sheet(isPresented: $showVideoPicker) {
            PhotoVideoPicker(
                onMediaPicked: { url in
                    showVideoPicker = false

                    // PhotoVideoPicker always returns video files - extract audio
                    Task {
                        isExtractingAudio = true
                        do {
                            let audioURL = try await AudioExtractor.extractAudio(from: url)

                            // The temp video file from Photos will be cleaned up by system,
                            // but we can explicitly delete it to free space immediately
                            try? FileManager.default.removeItem(at: url)

                            await MainActor.run {
                                isExtractingAudio = false
                                pendingAudioURL = audioURL
                            }
                        } catch {
                            // Clean up temp video file even on error
                            try? FileManager.default.removeItem(at: url)

                            await MainActor.run {
                                isExtractingAudio = false
                                extractionErrorMessage = error.localizedDescription
                                showExtractionError = true
                            }
                        }
                    }
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
                onExit: {
                    pendingAudioURL = nil
                    selectedTab = 0  // Go back to recordings home tab
                },
                onSaveComplete: { recording in
                    pendingAudioURL = nil
                    // fullScreenCover will auto-dismiss when pendingAudioURL becomes nil
                    // Ensure we're on recordings tab
                    selectedTab = 0
                }
            )
        }
    }
}
