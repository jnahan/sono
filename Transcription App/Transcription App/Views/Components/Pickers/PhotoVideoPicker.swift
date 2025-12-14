import SwiftUI
import PhotosUI
import AVFoundation

struct PhotoVideoPicker: UIViewControllerRepresentable {
    let onMediaPicked: (URL) -> Void
    let onCancel: (() -> Void)?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        
        config.filter = .videos
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onMediaPicked: onMediaPicked, onCancel: onCancel)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onMediaPicked: (URL) -> Void
        let onCancel: (() -> Void)?
        
        init(onMediaPicked: @escaping (URL) -> Void, onCancel: (() -> Void)?) {
            self.onMediaPicked = onMediaPicked
            self.onCancel = onCancel
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else {
                DispatchQueue.main.async {
                    self.onCancel?()
                }
                return
            }
            
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url, error == nil else {
                    DispatchQueue.main.async {
                        self.onCancel?()
                    }
                    return
                }
                
                self.copyVideoToAppDirectory(from: url)
            }
        }
        
        private func copyVideoToAppDirectory(from sourceURL: URL) {
            // Copy to our temp directory (PHPicker temp files get deleted too quickly)
            // The video will stay in the user's Photos library (this is just a copy for extraction)
            do {
                let fileManager = FileManager.default

                // Create temp directory for video imports
                let tempDir = fileManager.temporaryDirectory
                    .appendingPathComponent("VideoImports", isDirectory: true)

                try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

                // Create unique filename
                let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
                let ext = sourceURL.pathExtension
                let destinationURL = tempDir.appendingPathComponent("video-\(timestamp).\(ext)")

                // Copy the file to our temp directory
                try fileManager.copyItem(at: sourceURL, to: destinationURL)

                DispatchQueue.main.async {
                    self.onMediaPicked(destinationURL)
                }

            } catch {
                Logger.error("PhotoVideoPicker", "Failed to copy video: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.onCancel?()
                }
            }
        }
    }
}
