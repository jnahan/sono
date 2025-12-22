import SwiftData
import Foundation

/// Represents a collection for organizing recordings
/// Users can create collections and assign recordings to them for better organization
@Model
class Collection: Hashable {
    // MARK: - Identifiers
    @Attribute(.unique) var id: UUID

    // MARK: - Basic Info
    var name: String
    var createdAt: Date

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var recordings: [Recording] = []    // All recordings in this collection

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }

    // MARK: - Hashable Conformance
    static func == (lhs: Collection, rhs: Collection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
