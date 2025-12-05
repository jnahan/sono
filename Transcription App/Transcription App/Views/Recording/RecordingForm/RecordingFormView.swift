import SwiftUI
import SwiftData
import Foundation

struct RecordingFormView: View {
    @Binding var isPresented: Bool
    let audioURL: URL?
    let existingRecording: Recording?
    let collections: [Collection]
    let modelContext: ModelContext
    let onTranscriptionComplete: () -> Void
    let onExit: (() -> Void)?
    
    @StateObject private var viewModel: RecordingFormViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(
        isPresented: Binding<Bool>,
        audioURL: URL?,
        existingRecording: Recording?,
        collections: [Collection],
        modelContext: ModelContext,
        onTranscriptionComplete: @escaping () -> Void,
        onExit: (() -> Void)?
    ) {
        self._isPresented = isPresented
        self.audioURL = audioURL
        self.existingRecording = existingRecording
        self.collections = collections
        self.modelContext = modelContext
        self.onTranscriptionComplete = onTranscriptionComplete
        self.onExit = onExit
        self._viewModel = StateObject(wrappedValue: RecordingFormViewModel(audioURL: audioURL, existingRecording: existingRecording))
    }
    
    var body: some View {
        ZStack {
            Color.warmGray50
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                if viewModel.isEditing {
                    CustomTopBar(
                        title: "Edit Recording",
                        leftIcon: "caret-left",
                        onLeftTap: {
                            isPresented = false
                            dismiss()
                        }
                    )
                    .padding(.top, 12)
                } else {
                    CustomTopBar(
                        title: "New recording",
                        leftIcon: "x",
                        onLeftTap: {
                            viewModel.showExitConfirmation = true
                        }
                    )
                    .padding(.top, 12)
                    
                    VStack(spacing: 8) {
                        Text("Transcribing audio")
                            .font(.custom("LibreBaskerville-Regular", size: 24))
                            .foregroundColor(.baseBlack)
                        
                        Text("Please do not close the app\nuntil transcription is complete")
                            .font(.system(size: 16))
                            .foregroundColor(.warmGray500)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                
                ScrollView {
                    // Form fields
                    VStack(spacing: 24) {
                        // Title field
                        VStack(alignment: .leading, spacing: 8) {
                            InputLabel(text: "Title")
                            InputField(
                                text: $viewModel.title,
                                placeholder: "Title",
                                error: viewModel.titleError
                            )
                        }
                        
                        // Collection field
                        VStack(alignment: .leading, spacing: 8) {
                            InputLabel(text: "Collection")
                            InputField(
                                text: Binding(
                                    get: { viewModel.selectedCollection?.name ?? "" },
                                    set: { _ in }
                                ),
                                placeholder: "Select collection",
                                showChevron: true,
                                onTap: { viewModel.showCollectionPicker = true }
                            )
                        }
                        
                        // Note field
                        VStack(alignment: .leading, spacing: 8) {
                            InputLabel(text: "Note")
                            InputField(
                                text: $viewModel.note,
                                placeholder: "Write a note for yourself...",
                                isMultiline: true,
                                height: 200,
                                error: viewModel.noteError
                            )
                        }
                    }
                    .padding(.horizontal, AppConstants.UI.Spacing.large)
                    .padding(.top, viewModel.isEditing ? 24 : 0)
                }
                
                Spacer()
                
                // Save button
                Button {
                    viewModel.validateForm()
                    if viewModel.isFormValid {
                        if viewModel.isEditing {
                            viewModel.saveEdit()
                            isPresented = false
                            dismiss()
                        } else {
                            viewModel.saveRecording(modelContext: modelContext) {
                                onTranscriptionComplete()
                                isPresented = false
                            }
                        }
                    }
                } label: {
                    Text(viewModel.saveButtonText)
                }
                .buttonStyle(AppButtonStyle())
                .disabled(viewModel.isTranscribing)
            }
        }
        .sheet(isPresented: $viewModel.showCollectionPicker) {
            CollectionPickerView(
                collections: collections,
                selectedCollection: $viewModel.selectedCollection,
                modelContext: modelContext,
                isPresented: $viewModel.showCollectionPicker
            )
        }
        .sheet(isPresented: $viewModel.showExitConfirmation) {
            ConfirmationSheet(
                isPresented: $viewModel.showExitConfirmation,
                title: "Discard recording?",
                message: "Your recording will be lost if you exit now. Are you sure you want to continue?",
                confirmButtonText: "Discard recording",
                cancelButtonText: "Continue editing",
                onConfirm: {
                    viewModel.cleanupAudioFile()
                    isPresented = false
                    onExit?()
                }
            )
        }
        .onAppear {
            viewModel.setupForm()
            viewModel.startTranscriptionIfNeeded()
        }
        .navigationBarHidden(true)
    }
}

