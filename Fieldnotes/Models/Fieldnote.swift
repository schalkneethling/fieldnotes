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

enum FieldnotesSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static let models: [any PersistentModel.Type] = [Fieldnote.self, ArchiveUsage.self]

    @Model
    final class Fieldnote {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var text: String
        var emoji: String?
        @Attribute(.externalStorage) var photoData: Data?

        init(
            id: UUID = UUID(),
            text: String,
            emoji: String? = nil,
            photoData: Data? = nil,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.createdAt = createdAt
            self.text = text
            self.emoji = emoji
            self.photoData = photoData
        }

        convenience init(record: FieldnotesArchiveRecord) {
            self.init(
                id: record.id,
                text: record.text,
                emoji: record.emoji,
                photoData: record.photoData,
                createdAt: Date(timeIntervalSince1970: record.createdAtUnixSeconds)
            )
        }
    }

    @Model
    final class ArchiveUsage {
        @Attribute(.unique) var key: String
        var totalPhotoBytes: Int
        var estimatedArchiveBytes: Int

        init(
            key: String,
            totalPhotoBytes: Int,
            estimatedArchiveBytes: Int
        ) {
            self.key = key
            self.totalPhotoBytes = totalPhotoBytes
            self.estimatedArchiveBytes = estimatedArchiveBytes
        }
    }
}

typealias Fieldnote = FieldnotesSchemaV2.Fieldnote
typealias FieldnotesArchiveUsageModel = FieldnotesSchemaV2.ArchiveUsage
