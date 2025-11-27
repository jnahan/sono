import SwiftUI
import SwiftData

struct MainTabView: View {
    // MARK: - Environment & Queries
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [Folder]
    
    // MARK: - State
    @State private var selectedTab = 0
    @State private var showPlusButton = true
    
    // MARK: - Sheet States
    @State private var showAddSheet = false
    @State private var showRecorderView = false
    @State private var showFilePicker = false
    @State private var showTranscriptionDetail = false
    @State private var pendingAudioURL: URL? = nil
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Tab Bar
            TabView(selection: $selectedTab) {
                RecordingsView()
                    .environment(\.showPlusButton, $showPlusButton)
                    .tabItem {
                        Label("Recordings", systemImage: "waveform")
                    }
                    .tag(0)
                
                // Placeholder for center plus button
                Color.clear
                    .tabItem {
                        Label("", systemImage: "")
                    }
                    .tag(1)
                
                FoldersView()
                    .environment(\.showPlusButton, $showPlusButton)
                    .tabItem {
                        Label("Folders", systemImage: "folder")
                    }
                    .tag(2)
            }
            
            // Custom Plus Button Overlay
            if showPlusButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        Button {
                            showAddSheet = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 56, height: 56)
                                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NewRecordingSheet(
                onRecordAudio: { showRecorderView = true },
                onUploadFile: { showFilePicker = true }
            )
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $showRecorderView) {
            RecorderView()
        }
        .sheet(isPresented: $showFilePicker) {
            AudioFilePicker { url in
                pendingAudioURL = url
                showFilePicker = false
                showTranscriptionDetail = true
            }
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

// MARK: - Environment Key
private struct ShowPlusButtonKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(true)
}

extension EnvironmentValues {
    var showPlusButton: Binding<Bool> {
        get { self[ShowPlusButtonKey.self] }
        set { self[ShowPlusButtonKey.self] = newValue }
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .modelContainer(for: [Recording.self, RecordingSegment.self, Folder.self], inMemory: true)
}
