import Foundation
import SwiftData

/// Represents a single audio recording with its transcription
/// Contains the audio file, full transcribed text, segments with timestamps,
/// optional notes, and optional folder organization
@Model
class Recording {
    // MARK: - Identifiers
    @Attribute(.unique) var id: UUID
    
    // MARK: - Basic Info
    var title: String
    var recordedAt: Date
    var language: String
    
    // MARK: - Audio File
    var fileURL: URL?
    var filePath: String?
    
    // MARK: - Transcription
    var fullText: String // Complete transcription
    @Relationship(deleteRule: .cascade)
    var segments: [RecordingSegment] = [] // Timestamped segments
    
    // MARK: - User Notes
    var notes: String
    
    // MARK: - Organization
    @Relationship(inverse: \Folder.recordings)
    var folder: Folder?
    
    // MARK: - Computed Properties
    var resolvedURL: URL? {
        if let fileURL { return fileURL }
        if let filePath { return URL(fileURLWithPath: filePath) }
        return nil
    }
    
    init(
        title: String,
        fileURL: URL?,
        filePath: String?,
        fullText: String,
        language: String,
        notes: String = "",
        segments: [RecordingSegment] = [],
        folder: Folder? = nil,
        recordedAt: Date
    ) {
        self.id = UUID()
        self.title = title
        self.fileURL = fileURL
        self.filePath = filePath
        self.fullText = fullText
        self.language = language
        self.notes = notes
        self.segments = segments
        self.folder = folder
        self.recordedAt = recordedAt
    }
}
