import SwiftUI
import SwiftData
import Foundation

struct RecordingFormView: View {
    @Binding var isPresented: Bool
    let audioURL: URL?
    let existingRecording: Recording?
    let collections: [Collection]
    let modelContext: ModelContext
    let onExit: (() -> Void)?
    var onSaveComplete: ((Recording) -> Void)? = nil

    @StateObject private var viewModel: RecordingFormViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    init(
        isPresented: Binding<Bool>,
        audioURL: URL?,
        existingRecording: Recording?,
        collections: [Collection],
        modelContext: ModelContext,
        onExit: (() -> Void)?,
        onSaveComplete: ((Recording) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.audioURL = audioURL
        self.existingRecording = existingRecording
        self.collections = collections
        self.modelContext = modelContext
        self.onExit = onExit
        self.onSaveComplete = onSaveComplete
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
                            // Save recording and dismiss - go back to home
                            if let savedRecording = viewModel.saveRecording(modelContext: modelContext) {
                                // Call onSaveComplete callback - parent will handle dismissal
                                onSaveComplete?(savedRecording)
                                // Set isPresented to false to trigger binding update
                                isPresented = false
                            }
                        }
                    }
                } label: {
                    Text(viewModel.saveButtonText)
                }
                .buttonStyle(AppButtonStyle())
                .disabled(!viewModel.isFormValid)
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
                viewModel.setTranscriptionContext(modelContext)
            }
            viewModel.startTranscriptionIfNeeded()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Handle app backgrounding during transcription
            if newPhase == .background && !viewModel.isEditing {
                print("📱 [RecordingForm] App backgrounded - saving recording state")
                // Save current state even if transcription is still in progress
                _ = viewModel.saveRecording(modelContext: modelContext)

                // Mark that we were backgrounded during transcription
                if viewModel.isTranscribing {
                    print("📱 [RecordingForm] Backgrounded during transcription")
                    viewModel.markBackgrounded()
                }
            } else if newPhase == .active && oldPhase == .background && !viewModel.isEditing {
                print("📱 [RecordingForm] App returned from background")
                // Check if we need to resume transcription
                viewModel.handleReturnFromBackground(modelContext: modelContext)
            }
        }
        .navigationBarHidden(true)
    }
}

