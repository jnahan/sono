import Foundation
import WhisperKit
import SwiftData

@Model
final class Recording {
    var title: String
    var fileURL: URL
    var createdAt: Date
    var transcription: String?
    var whisperSegmentsData: Data? // save directly as JSON
    
    init(title: String, fileURL: URL) {
        self.title = title
        self.fileURL = fileURL
        self.createdAt = Date()
    }
}
