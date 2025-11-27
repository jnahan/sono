import SwiftData
import Foundation

/// Represents a folder for organizing recordings
/// Users can create folders and assign recordings to them for better organization
@Model
class Folder {
    // MARK: - Identifiers
    @Attribute(.unique) var id: UUID
    
    // MARK: - Basic Info
    var name: String
    var createdAt: Date
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade)
    var recordings: [Recording] = []    // All recordings in this folder
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
