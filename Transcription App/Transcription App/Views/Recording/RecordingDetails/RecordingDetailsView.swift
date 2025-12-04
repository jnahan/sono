import SwiftUI
import SwiftData
import AVFoundation

struct RecordingDetailsView: View {
    let recording: Recording
    @StateObject private var audioPlayer = Player()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var collections: [Collection]
    
    @State private var showNotePopup = false
    @State private var showEditRecording = false
    @State private var showDeleteConfirm = false
    @State private var showMenu = false
    
    var body: some View {
        ZStack {
            Color.warmGray50
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Top Bar
                CustomTopBar(
                    title: "",
                    leftIcon: "caret-left",
                    rightIcon: "dots-three",
                    onLeftTap: { dismiss() },
                    onRightTap: { showMenu = true }
                )
                
                // Header
                VStack(spacing: 12) {
                    Image("asterisk")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)

                    VStack(spacing: 8) {
                        Text(TimeFormatter.relativeDate(from: recording.recordedAt))
                            .font(.system(size: 14))
                            .foregroundColor(.warmGray500)
                        
                        Text(recording.title)
                            .font(.custom("LibreBaskerville-Medium", size: 24))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                
                // Scrollable Transcript Area
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !recording.segments.isEmpty {
                            ForEach(recording.segments) { segment in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(TimeFormatter.formatTimestamp(segment.start))
                                        .font(.system(size: 14))
                                        .foregroundColor(.warmGray400)
                                    
                                    Text(segment.text)
                                        .font(.system(size: 16))
                                        .foregroundColor(.baseBlack)
                                }
                            }
                        } else {
                            Text(recording.fullText)
                                .font(.system(size: 16))
                                .foregroundColor(.baseBlack)
                                .lineSpacing(4)
                        }
                    }
                    .padding(.horizontal, AppConstants.UI.Spacing.large)
                    .padding(.top, 24)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 164)
                    }
                }
                
                Spacer()
            }
            
            // Audio Player Controls (Fixed at bottom)
            VStack {
                Spacer()
                
                AudioPlayerControls(
                    audioPlayer: audioPlayer,
                    audioURL: recording.resolvedURL,
                    fullText: recording.fullText,
                    onNotePressed: {
                        showNotePopup = true
                    },
                    onSharePressed: {
                        if let url = recording.resolvedURL {
                            ShareHelper.shareItems([recording.fullText, url])
                        } else {
                            ShareHelper.shareText(recording.fullText)
                        }
                    }
                )
            }
            
            // Note Overlay
            if showNotePopup {
                NoteOverlay(
                    isPresented: $showNotePopup,
                    noteText: recording.notes
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showNotePopup)
        .navigationBarHidden(true)
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Copy transcription") {
                UIPasteboard.general.string = recording.fullText
            }
            
            Button("Share transcription") {
                ShareHelper.shareText(recording.fullText)
            }
            
            Button("Export audio") {
                if let url = recording.resolvedURL {
                    ShareHelper.shareFile(at: url)
                }
            }
            
            Button("Edit") {
                showEditRecording = true
            }
            
            Button("Delete", role: .destructive) {
                showDeleteConfirm = true
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditRecording) {
            RecordingFormView(
                isPresented: $showEditRecording,
                audioURL: nil,
                existingRecording: recording,
                collections: collections,
                modelContext: modelContext,
                onTranscriptionComplete: {},
                onExit: nil
            )
        }
        .sheet(isPresented: $showDeleteConfirm) {
            ConfirmationSheet(
                isPresented: $showDeleteConfirm,
                title: "Delete recording?",
                message: "Are you sure you want to delete \"\(recording.title)\"? This action cannot be undone.",
                confirmButtonText: "Delete recording",
                cancelButtonText: "Cancel",
                onConfirm: {
                    modelContext.delete(recording)
                    showDeleteConfirm = false
                    dismiss()
                }
            )
        }
        .onAppear {
            if let url = recording.resolvedURL {
                audioPlayer.loadAudio(url: url)
            }
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
}
