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
    @FocusState private var isTitleFocused: Bool
    
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
                }

                ScrollView {
                    // Form fields
                    VStack(spacing: 20) {
                        // Title field
                        VStack(alignment: .leading, spacing: 6) {
                            InputLabel(text: "Title")
                            InputField(
                                text: $viewModel.title,
                                placeholder: "Title",
                                error: viewModel.titleError
                            )
                            .focused($isTitleFocused)
                        }

                        // Collection field
                        VStack(alignment: .leading, spacing: 6) {
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
                        VStack(alignment: .leading, spacing: 6) {
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
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
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
                .buttonStyle(PrimaryButtonStyle())
                // Disable button when validation fails - errors show in real-time so user knows why
                .disabled(!viewModel.isFormValid)
            }
        }
        .overlay(alignment: .top) {
            if viewModel.showErrorToast {
                ToastView(
                    message: viewModel.errorMessage,
                    isPresented: $viewModel.showErrorToast,
                    isError: true
                )
                .padding(.top, 8)
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
                    // Clean up first, then dismiss
                    viewModel.cleanupOnExit(modelContext: modelContext)
                    // Small delay to ensure deletion saves before dismissing
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        isPresented = false
                        onExit?()
                    }
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

                // Autofocus on title field for new recordings
                #if !os(macOS)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTitleFocused = true
                }
                #endif
            }
            viewModel.startTranscriptionIfNeeded()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Handle app backgrounding during transcription
            if newPhase == .background && !viewModel.isEditing {
                Logger.info("RecordingForm", "App backgrounded - saving recording state")
                // Save current state even if transcription is still in progress
                _ = viewModel.saveRecording(modelContext: modelContext)

                // Mark that we were backgrounded during transcription
                if viewModel.isTranscribing {
                    Logger.info("RecordingForm", "Backgrounded during transcription")
                    viewModel.markBackgrounded()
                }
            } else if newPhase == .active && oldPhase == .background && !viewModel.isEditing {
                Logger.info("RecordingForm", "App returned from background")
                // Check if we need to resume transcription
                viewModel.handleReturnFromBackground(modelContext: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            // Low memory warning - save recording state
            if viewModel.isTranscribing && !viewModel.isEditing {
                Logger.warning("RecordingForm", "Low memory warning during transcription - saving state")
                _ = viewModel.saveRecording(modelContext: modelContext)
                viewModel.handleLowMemory(modelContext: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            // App is being terminated - save recording state
            if viewModel.isTranscribing && !viewModel.isEditing {
                Logger.warning("RecordingForm", "App terminating during transcription - saving state")
                _ = viewModel.saveRecording(modelContext: modelContext)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

