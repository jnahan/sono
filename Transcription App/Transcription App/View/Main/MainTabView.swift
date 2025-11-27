import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [Folder]
    
    @State private var selectedTab = 0
    @State private var showAddSheet = false
    @State private var showRecorderScreen = false
    @State private var showFilePicker = false
    @State private var showPlusButton = true
    
    // For handling imported file
    @State private var showTranscriptionDetail = false
    @State private var pendingAudioURL: URL? = nil
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ContentView()
                    .environment(\.showPlusButton, $showPlusButton)
                    .tabItem {
                        Label("Recordings", systemImage: "waveform")
                    }
                    .tag(0)
                
                // Placeholder for middle tab (will be handled by custom button)
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
            
            // Custom Plus Button
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
                    .padding(.bottom, 8) // Adjust to align with tab bar
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddRecordingSheet(
                onRecordAudio: {
                    showRecorderScreen = true
                },
                onUploadFile: {
                    showFilePicker = true
                }
            )
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $showRecorderScreen) {
            RecorderScreen()
        }
        .sheet(isPresented: $showFilePicker) {
            AudioFilePicker { url in
                print("File imported: \(url)")
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
            TranscriptionDetailView(
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

// Environment key for showing/hiding plus button
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
