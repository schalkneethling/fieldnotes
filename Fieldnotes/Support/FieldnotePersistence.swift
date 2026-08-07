import Foundation
import SwiftData

@ModelActor
actor FieldnotePersistenceStore {
    func save(
        text: String,
        emoji: String?,
        photoData: Data?,
        createdAt: Date = .now,
        archiveLimits: FieldnotesArchiveLimits = .version1
    ) throws -> UUID {
        let fieldnote = Fieldnote(text: text, emoji: emoji, photoData: photoData, createdAt: createdAt)
        let existingRecords = try modelContext.fetch(FetchDescriptor<Fieldnote>())
            .map(FieldnotesArchiveRecord.init)
        _ = try FieldnotesArchiveCodec.makeArchive(
            from: existingRecords + [FieldnotesArchiveRecord(fieldnote: fieldnote)],
            exportedAt: Date(timeIntervalSince1970: 0),
            limits: archiveLimits
        )
        modelContext.insert(fieldnote)

        do {
            if modelContext.hasChanges {
                try modelContext.save()
            }
            return fieldnote.id
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
