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
    @Environment(\.scenePhase) private var scenePhase
    
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
            
            // Error Toast
            VStack {
                if viewModel.showErrorToast {
                    ErrorToastView(
                        message: viewModel.errorMessage,
                        isPresented: $viewModel.showErrorToast
                    )
                }
                Spacer()
            }
            .zIndex(1000)

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
                        title: "",
                        leftIcon: "x",
                        onLeftTap: {
                            viewModel.showExitConfirmation = true
                        }
                    )
                    .padding(.top, 12)
                    
                    VStack(spacing: 8) {
                        if viewModel.isModelLoading {
                            Text("Downloading model...")
                                .font(.custom("LibreBaskerville-Regular", size: 24))
                                .foregroundColor(.baseBlack)
                            
                            Text("Please wait while the transcription model loads")
                                .font(.system(size: 16))
                                .foregroundColor(.warmGray500)
                                .multilineTextAlignment(.center)
                        } else if viewModel.isModelWarming {
                            Text("Warming up model...")
                                .font(.custom("LibreBaskerville-Regular", size: 24))
                                .foregroundColor(.baseBlack)
                            
                            Text("Please wait while the model initializes")
                                .font(.system(size: 16))
                                .foregroundColor(.warmGray500)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Transcribing audio")
                                .font(.custom("LibreBaskerville-Regular", size: 24))
                                .foregroundColor(.baseBlack)
                            
                            if viewModel.isTranscribing {
                                Text("\(Int(viewModel.transcriptionProgress * 100))% complete")
                                    .font(.system(size: 16))
                                    .foregroundColor(.warmGray500)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Please do not close the app\nuntil transcription is complete")
                                    .font(.system(size: 16))
                                    .foregroundColor(.warmGray500)
                                    .multilineTextAlignment(.center)
                            }
                        }
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
                                placeholder: "Add a note",
                                isMultiline: true,
                                height: 200,
                                error: viewModel.noteError
                            )
                        }
                    }
                    .padding(.horizontal, AppConstants.UI.Spacing.large)
                    .padding(.top, viewModel.isEditing ? 24 : 0)
                }
                .scrollDismissesKeyboard(.interactively)

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
                            // Guard: Don't allow saving if model is still loading
                            guard !viewModel.isModelLoading else {
                                viewModel.showError("Please wait for the model to finish loading before saving.")
                                return
                            }
                            
                            // Button is already disabled if transcription isn't complete, so no need for error
                            
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
                .disabled(viewModel.isTranscribing || viewModel.isModelLoading || viewModel.isModelWarming)
            }
        }
        .sheet(isPresented: $viewModel.showCollectionPicker) {
            CollectionPickerSheet(
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
            // Auto-save recording before starting transcription for crash recovery
            if !viewModel.isEditing {
                viewModel.autoSaveRecording(modelContext: modelContext)
                viewModel.markTranscriptionStarted(modelContext: modelContext)
            }
            viewModel.startTranscriptionIfNeeded()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Save recording state when app goes to background
            if newPhase == .background && !viewModel.isEditing {
                print("📱 [RecordingForm] App backgrounded - saving recording state")
                // Save current state even if transcription is still in progress
                viewModel.saveRecording(modelContext: modelContext) {
                    // No-op: just ensuring state is saved
                }
            }
        }
        .navigationBarHidden(true)
    }
}

