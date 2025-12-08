import SwiftUI

struct ModelItem: Identifiable {
    let id = UUID()
    let name: String  // "tiny", "base", "small"
    let title: String  // "Tiny", "Base", "Small"
    let description: String  // "Fastest", "Balanced", "Highest quality"
}

struct ModelSelectionView: View {
    @Binding var selectedModel: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ModelSelectionViewModel()
    @State private var modelToDelete: String?
    @State private var showDeleteConfirmation = false

    private let models: [ModelItem] = [
        ModelItem(name: "tiny", title: "Tiny", description: "Fastest"),
        ModelItem(name: "base", title: "Base", description: "Balanced"),
        ModelItem(name: "small", title: "Small", description: "Highest quality")
    ]

    var body: some View {
        VStack(spacing: 0) {
            CustomTopBar(
                title: "Model",
                leftIcon: "caret-left",
                onLeftTap: { dismiss() }
            )
            .padding(.top, 12)

            List {
                ForEach(models) { model in
                    modelRow(for: model)
                        .buttonStyle(.plain)
                        .listRowBackground(Color.warmGray50)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.warmGray50)
        }
        .background(Color.warmGray50)
        .navigationBarHidden(true)
        .sheet(isPresented: $showDeleteConfirmation) {
            ConfirmationSheet(
                isPresented: $showDeleteConfirmation,
                title: "Delete \(modelToDelete?.capitalized ?? "model")?",
                message: "This will free up storage space. You can download it again later if needed.",
                confirmButtonText: "Delete",
                cancelButtonText: "Cancel",
                onConfirm: {
                    // Delete the model
                    if let model = modelToDelete {
                        viewModel.deleteModel(model)
                    }
                    // Clear the state
                    modelToDelete = nil
                }
            )
        }
        .onAppear {
            viewModel.checkDownloadStates()

            // Auto-download the currently selected model if not downloaded
            Task {
                await viewModel.ensureDefaultModelDownloaded(selectedModel.lowercased())
            }
        }
    }

    @ViewBuilder
    private func modelRow(for model: ModelItem) -> some View {
        Button(action: {
            // Don't allow interaction while downloading
            guard !viewModel.isDownloading(model.name) else { return }

            if viewModel.isDownloaded(model.name) {
                // Model is downloaded, select it
                selectedModel = model.title
                SettingsManager.shared.transcriptionModel = model.name
                dismiss()
            } else {
                // Model not downloaded, start download
                Task {
                    await viewModel.downloadModel(model.name)
                    // After download completes, select it
                    if viewModel.isDownloaded(model.name) {
                        selectedModel = model.title
                        SettingsManager.shared.transcriptionModel = model.name
                        dismiss()
                    }
                }
            }
        }) {
            HStack(spacing: 12) {
                // Download status indicator on the left
                if viewModel.isDownloading(model.name) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 24, height: 24)
                } else if viewModel.isDownloaded(model.name) {
                    // Check-circle - tappable to delete model
                    Image("check-circle")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color.warmGray500)
                        .onTapGesture {
                            // Only allow deletion if not currently selected
                            if selectedModel != model.title {
                                modelToDelete = model.name
                                showDeleteConfirmation = true
                            }
                        }
                } else {
                    // Download icon - tappable to download
                    Image("download")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color.warmGray500)
                        .onTapGesture {
                            Task {
                                await viewModel.downloadModel(model.name)
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.title)
                        .font(.system(size: 16))
                        .foregroundColor(.baseBlack)

                    Text(model.description)
                        .font(.interMedium(size: 14))
                        .foregroundColor(.warmGray400)
                }

                Spacer()

                // Show selection checkmark if selected
                if selectedModel == model.title {
                    Image("check-bold")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model

@MainActor
class ModelSelectionViewModel: ObservableObject {
    @Published private var downloadStates: [String: Bool] = [:]
    @Published private var downloadingStates: [String: Bool] = [:]

    func checkDownloadStates() {
        print("🔍 [ModelSelection] Checking download states for all models")
        let models = ["tiny", "base", "small"]
        for model in models {
            let isDownloaded = ModelDownloadManager.shared.isModelDownloaded(model)
            downloadStates[model] = isDownloaded
            print("🔍 [ModelSelection] Model '\(model)' downloaded: \(isDownloaded)")
        }
    }

    func isDownloaded(_ modelName: String) -> Bool {
        return downloadStates[modelName] ?? false
    }

    func isDownloading(_ modelName: String) -> Bool {
        return downloadingStates[modelName] ?? false
    }

    func downloadModel(_ modelName: String) async {
        print("📥 [ModelSelection] Starting download for model '\(modelName)'")
        downloadingStates[modelName] = true

        // Download happens automatically when initializing WhisperKit
        // Temporarily set the model to trigger download, then restore original
        let previousModel = SettingsManager.shared.transcriptionModel
        let previousModelValue = previousModel

        // Change to the new model
        SettingsManager.shared.transcriptionModel = modelName

        // Trigger download by preloading
        await TranscriptionService.shared.preloadModel()

        // IMPORTANT: Restore the previous model setting
        // This ensures we don't accidentally change the user's selected model
        SettingsManager.shared.transcriptionModel = previousModelValue

        downloadingStates[modelName] = false

        // Re-check download state to update UI
        let isDownloaded = ModelDownloadManager.shared.isModelDownloaded(modelName)
        downloadStates[modelName] = isDownloaded
        print("🔄 [ModelSelection] Download complete for '\(modelName)': \(isDownloaded)")
    }

    func deleteModel(_ modelName: String) {
        let success = TranscriptionService.shared.deleteModel(modelName)
        if success {
            downloadStates[modelName] = false
            print("✅ [ModelSelection] Successfully deleted model '\(modelName)'")
        } else {
            print("❌ [ModelSelection] Failed to delete model '\(modelName)'")
        }
    }

    func ensureDefaultModelDownloaded(_ modelName: String) async {
        // Check if the default model is already downloaded or downloading
        if isDownloaded(modelName) || isDownloading(modelName) {
            print("ℹ️ [ModelSelection] Model '\(modelName)' already downloaded or downloading")
            return
        }

        // Start downloading the default model
        print("📥 [ModelSelection] Auto-downloading default model '\(modelName)'")
        await downloadModel(modelName)
    }
}
