import SwiftUI
import SwiftData
import AVFoundation
import UIKit

enum RecordingDetailTab {
    case transcript
    case summary
    case askSono
}

struct RecordingDetailsView: View {
    let recording: Recording
    var onDismiss: (() -> Void)? = nil

    @StateObject private var audioPlayback = AudioPlaybackService()
    @StateObject private var viewModel: RecordingDetailsViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Collection.name) private var collections: [Collection]

    init(recording: Recording, onDismiss: (() -> Void)? = nil) {
        self.recording = recording
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: RecordingDetailsViewModel(recording: recording))
    }

    @State private var showEditRecording = false
    @State private var showDeleteConfirm = false
    @State private var selectedTab: RecordingDetailTab = .transcript

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                CustomTopBar(
                    title: "",
                    leftIcon: "caret-left",
                    rightIcon: "dots-three-bold",
                    onLeftTap: {
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    },
                    onRightTap: {
                        ActionSheetManager.shared.show(actions: [
                            ActionItem(title: "Copy transcription", icon: "copy", action: {
                                UIPasteboard.general.string = recording.fullText
                            }),
                            ActionItem(title: "Share transcription", icon: "export", action: {
                                ShareHelper.shareTranscription(recording.fullText, title: recording.title)
                            }),
                            ActionItem(title: "Export audio", icon: "waveform", action: {
                                if let url = recording.resolvedURL {
                                    ShareHelper.shareFile(at: url)
                                }
                            }),
                            ActionItem(title: "Edit", icon: "pencil-simple", action: {
                                showEditRecording = true
                            }),
                            ActionItem(title: "Delete", icon: "trash", action: {
                                showDeleteConfirm = true
                            }, isDestructive: true)
                        ])
                    }
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(TimeFormatter.dateWithTime(from: recording.recordedAt))
                        .font(.dmSansMedium(size: 14))
                        .foregroundColor(.warmGray400)

                    Text(recording.title)
                        .font(.dmSansSemiBold(size: 24))
                        .foregroundColor(.baseBlack)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                HStack(spacing: 16) {
                    TabButton(
                        title: "Transcript",
                        isSelected: selectedTab == .transcript,
                        action: { selectedTab = .transcript }
                    )

                    TabButton(
                        title: "Summary",
                        isSelected: selectedTab == .summary,
                        action: { selectedTab = .summary }
                    )

                    TabButton(
                        title: "Ask Sono",
                        isSelected: selectedTab == .askSono,
                        action: { selectedTab = .askSono }
                    )

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                VStack(spacing: 0) {
                    if selectedTab == .transcript {
                        transcriptView
                    } else if selectedTab == .summary {
                        summaryView
                    } else {
                        askSonoView
                    }
                }
                .padding(.top, 24)

                Spacer()
            }

            if selectedTab == .transcript {
                VStack {
                    Spacer()

                    RecordingPlayerBar(
                        audioService: audioPlayback,
                        audioURL: recording.resolvedURL,
                        fullText: recording.fullText,
                        onSharePressed: {
                            if let url = recording.resolvedURL {
                                if let transcriptionFileURL = ShareHelper.createTranscriptionFile(recording.fullText, title: recording.title) {
                                    ShareHelper.shareItems([transcriptionFileURL, url])
                                } else {
                                    ShareHelper.shareTranscription(recording.fullText, title: recording.title)
                                }
                            } else {
                                ShareHelper.shareTranscription(recording.fullText, title: recording.title)
                            }
                        }
                    )
                }
            }
        }
        .background(Color.warmGray50.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()

        .sheet(isPresented: $showEditRecording) {
            RecordingFormView(
                isPresented: $showEditRecording,
                audioURL: nil,
                existingRecording: recording,
                collections: collections,
                modelContext: modelContext,
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
                    TranscriptionProgressManager.shared.cancelTranscription(for: recording.id)
                    modelContext.delete(recording)
                    showDeleteConfirm = false
                    dismiss()
                }
            )
        }

        .onAppear {
            selectedTab = .transcript

            let audioManager = AudioPlayerManager.shared

            if let currentGlobal = audioManager.currentRecording, currentGlobal.id != recording.id {
                audioManager.stop()
            }

            if let currentGlobal = audioManager.currentRecording, currentGlobal.id == recording.id {
                let wasPlaying = audioManager.player.isPlaying
                let currentTime = audioManager.player.currentTime
                audioManager.stop()

                if let url = recording.resolvedURL {
                    audioPlayback.preload(url: url)
                    audioPlayback.seek(to: currentTime)
                    if wasPlaying { audioPlayback.play() }
                }
            } else {
                if let url = recording.resolvedURL {
                    audioPlayback.preload(url: url)
                }
            }

            audioManager.activeRecordingDetailsId = recording.id
        }

        .onDisappear {
            audioPlayback.stop()
            AudioPlayerManager.shared.clearActiveRecordingDetails()
        }
    }

    private var transcriptView: some View {
        TranscriptView(
            recording: recording,
            audioPlayback: audioPlayback,
            viewModel: viewModel
        )
        .id(recording.id)
    }

    private var summaryView: some View {
        SummaryView(recording: recording)
            .id(recording.id)
    }

    private var askSonoView: some View {
        AskSonoView(recording: recording)
            .id(recording.id)
    }
}
