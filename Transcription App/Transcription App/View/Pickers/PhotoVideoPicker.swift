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
                    print("❌ Failed to load video: \(error?.localizedDescription ?? "Unknown error")")
                    DispatchQueue.main.async {
                        self.onCancel?()
                    }
                    return
                }
                
                self.copyVideoToAppDirectory(from: url)
            }
        }
        
        private func copyVideoToAppDirectory(from sourceURL: URL) {
            do {
                let fileManager = FileManager.default
                
                let destinationDir = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                ).appendingPathComponent("Recordings", isDirectory: true)
                
                try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
                
                let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
                let ext = sourceURL.pathExtension
                let destinationURL = destinationDir.appendingPathComponent("video-\(timestamp).\(ext)")
                
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                
                print("✅ Video imported from library: \(destinationURL.lastPathComponent)")
                
                DispatchQueue.main.async {
                    self.onMediaPicked(destinationURL)
                }
                
            } catch {
                print("❌ Error copying video: \(error)")
                DispatchQueue.main.async {
                    self.onCancel?()
                }
            }
        }
    }
}
