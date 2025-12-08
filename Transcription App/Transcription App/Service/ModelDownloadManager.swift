import Foundation

/// Manages WhisperKit model downloads, detection, and deletion
class ModelDownloadManager {
    static let shared = ModelDownloadManager()

    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Model Detection

    /// Checks if a specific model is already downloaded
    /// - Parameter modelName: The model name to check (e.g., "base", "tiny", "small")
    /// - Returns: True if the model files exist locally, false otherwise
    func isModelDownloaded(_ modelName: String) -> Bool {
        guard let modelsBasePath = getModelsBasePath() else {
            print("❌ [ModelDownloadManager] Could not get models base path")
            return false
        }

        let modelVariants = [
            modelsBasePath.appendingPathComponent("openai_whisper-\(modelName)"),
            modelsBasePath.appendingPathComponent("openai_whisper-\(modelName).en"),
        ]

        for modelURL in modelVariants {
            if fileManager.fileExists(atPath: modelURL.path) {
                // Check for any .mlmodelc files or config.json
                if let contents = try? fileManager.contentsOfDirectory(atPath: modelURL.path),
                   contents.contains(where: { $0.hasSuffix(".mlmodelc") || $0 == "config.json" }) {
                    print("✅ [ModelDownloadManager] Found model '\(modelName)' at: \(modelURL.path)")
                    return true
                }
            }
        }

        return false
    }

    /// Gets all downloaded model names
    /// - Returns: Array of model names that are currently downloaded
    func getDownloadedModels() -> [String] {
        guard let modelsBasePath = getModelsBasePath() else {
            return []
        }

        guard let directories = try? fileManager.contentsOfDirectory(atPath: modelsBasePath.path) else {
            return []
        }

        let models = directories.compactMap { dir -> String? in
            // Extract model name from "openai_whisper-tiny" or "openai_whisper-tiny.en"
            if dir.hasPrefix("openai_whisper-") {
                let modelName = dir
                    .replacingOccurrences(of: "openai_whisper-", with: "")
                    .replacingOccurrences(of: ".en", with: "")
                return modelName
            }
            return nil
        }

        return Array(Set(models)) // Remove duplicates
    }

    // MARK: - Model Deletion

    /// Deletes a specific downloaded model
    /// - Parameter modelName: The model name to delete (e.g., "base", "tiny", "small")
    /// - Returns: True if deletion was successful, false otherwise
    func deleteModel(_ modelName: String) -> Bool {
        guard let modelsBasePath = getModelsBasePath() else {
            print("❌ [ModelDownloadManager] Could not get models base path")
            return false
        }

        var deleted = false

        let modelVariants = [
            modelsBasePath.appendingPathComponent("openai_whisper-\(modelName)"),
            modelsBasePath.appendingPathComponent("openai_whisper-\(modelName).en"),
        ]

        for modelURL in modelVariants {
            if fileManager.fileExists(atPath: modelURL.path) {
                do {
                    try fileManager.removeItem(at: modelURL)
                    print("✅ [ModelDownloadManager] Deleted model at: \(modelURL.path)")
                    deleted = true
                } catch {
                    print("❌ [ModelDownloadManager] Failed to delete model at \(modelURL.path): \(error)")
                }
            }
        }

        return deleted
    }

    /// Deletes all downloaded models
    func deleteAllModels() {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let huggingfacePath = documentsURL.appendingPathComponent("huggingface")

        guard fileManager.fileExists(atPath: huggingfacePath.path) else {
            print("ℹ️ [ModelDownloadManager] No models to delete")
            return
        }

        do {
            try fileManager.removeItem(at: huggingfacePath)
            print("✅ [ModelDownloadManager] Deleted all models")
        } catch {
            print("❌ [ModelDownloadManager] Failed to delete all models: \(error)")
        }
    }

    // MARK: - Helper Methods

    /// Gets the base path where WhisperKit stores models
    /// - Returns: URL to the models directory, or nil if it can't be determined
    private func getModelsBasePath() -> URL? {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        return documentsURL.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
    }

    /// Gets the total size of all downloaded models in bytes
    /// - Returns: Total size in bytes, or 0 if calculation fails
    func getTotalModelsSize() -> Int64 {
        guard let modelsBasePath = getModelsBasePath() else {
            return 0
        }

        guard fileManager.fileExists(atPath: modelsBasePath.path) else {
            return 0
        }

        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: modelsBasePath, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return totalSize
    }
}
