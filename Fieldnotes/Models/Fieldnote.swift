import Foundation
import SwiftData

enum FieldnotesSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = [Fieldnote.self]

    @Model
    final class Fieldnote {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var text: String
        var emoji: String?
        @Attribute(.externalStorage) var photoData: Data?

        init(text: String, emoji: String? = nil, photoData: Data? = nil, createdAt: Date = Date()) {
            self.id = UUID()
            self.createdAt = createdAt
            self.text = text
            self.emoji = emoji
            self.photoData = photoData
        }
    }
}

typealias Fieldnote = FieldnotesSchemaV1.Fieldnote
