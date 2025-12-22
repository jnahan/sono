import SwiftUI
import SwiftData
import UIKit
import AVFoundation

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Collection.name) private var collections: [Collection]

    @State private var selectedTab = 0

    @State private var showPlusButton = true

    @State private var isRecordingsRoot = true
    @State private var isCollectionsRoot = true

    @ObservedObject private var actionSheetManager = ActionSheetManager.shared

    @State private var showNewRecordingSheet = false
    @State private var showRecorderScreen = false
    @State private var showFilePicker = false
    @State private var showVideoPicker = false

    @State private var pendingAudioURL: URL?
    @State private var isExtractingAudio = false
    @State private var showExtractionError = false
    @State private var extractionErrorMessage = ""

    private var shouldShowCustomTabBar: Bool {
        let isRootForSelectedTab: Bool = {
            switch selectedTab {
            case 0: return isRecordingsRoot
            case 1: return isCollectionsRoot
            default: return true
            }
        }()
        return isRootForSelectedTab && showPlusButton
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {

                NavigationStack {
                    RecordingsView(
                        showPlusButton: $showPlusButton,
                        isRoot: $isRecordingsRoot
                    )
                }
                .tabItem { EmptyView() }
                .tag(0)

                NavigationStack {
                    CollectionsView(
                        isRoot: $isCollectionsRoot
                    )
                }
                .tabItem { EmptyView() }
                .tag(1)
            }

            VStack {
                Spacer()

                if shouldShowCustomTabBar {
                    VStack(spacing: 0) {
                        HStack(spacing: 40) {
                            Button {
                                selectedTab = 0
                            } label: {
                                Image(selectedTab == 0 ? "house-fill" : "house")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(selectedTab == 0 ? .baseBlack : .warmGray400)
                                    .frame(width: 32, height: 32)
                            }

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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.12), value: shouldShowCustomTabBar)
                }
            }

            if showNewRecordingSheet {
                NewRecordingSheet(
                    onRecordAudio: { showRecorderScreen = true },
                    onUploadFile: { showFilePicker = true },
                    onChooseFromPhotos: { showVideoPicker = true },
                    isPresented: $showNewRecordingSheet
                )
                .zIndex(1000)
            }

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
            let appearance = UITabBar.appearance()
            appearance.isHidden = true
            appearance.backgroundImage = UIImage()
            appearance.shadowImage = UIImage()
            appearance.backgroundColor = .clear
        }
        .fullScreenCover(isPresented: $showRecorderScreen) {
            RecorderView(
                onDismiss: {
                    showRecorderScreen = false
                },
                onSaveComplete: { recording in
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if recording.status != .completed {
                            NotificationCenter.default.post(
                                name: AppConstants.Notification.recordingSaved,
                                object: nil,
                                userInfo: ["recordingId": recording.id]
                            )
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showFilePicker) {
            MediaFilePicker(
                onFilePicked: { url, mediaType in
                    showFilePicker = false

                    if mediaType == .video {
                        Task {
                            isExtractingAudio = true
                            do {
                                let audioURL = try await AudioExtractor.extractAudio(from: url)
                                try? FileManager.default.removeItem(at: url)

                                await MainActor.run {
                                    isExtractingAudio = false
                                    pendingAudioURL = audioURL
                                }
                            } catch {
                                try? FileManager.default.removeItem(at: url)

                                await MainActor.run {
                                    isExtractingAudio = false
                                    extractionErrorMessage = error.localizedDescription
                                    showExtractionError = true
                                }
                            }
                        }
                    } else {
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

                    Task {
                        isExtractingAudio = true
                        do {
                            let audioURL = try await AudioExtractor.extractAudio(from: url)
                            try? FileManager.default.removeItem(at: url)

                            await MainActor.run {
                                isExtractingAudio = false
                                pendingAudioURL = audioURL
                            }
                        } catch {
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
                    selectedTab = 0
                },
                onSaveComplete: { recording in
                    pendingAudioURL = nil
                    selectedTab = 0

                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        if recording.status != .completed {
                            NotificationCenter.default.post(
                                name: AppConstants.Notification.recordingSaved,
                                object: nil,
                                userInfo: ["recordingId": recording.id]
                            )
                        }
                    }
                }
            )
        }
    }
}
