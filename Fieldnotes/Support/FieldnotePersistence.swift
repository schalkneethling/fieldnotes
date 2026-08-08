import Foundation
import SwiftData

protocol FieldnotePersistenceRepository {
    func persist(
        _ record: FieldnotesArchiveRecord,
        validatingUsage: (FieldnotesArchiveUsage) throws -> FieldnotesArchiveUsage
    ) throws
}

struct FieldnotePersistenceOperation<Repository: FieldnotePersistenceRepository> {
    let repository: Repository

    @discardableResult
    func save(
        text: String,
        emoji: String?,
        photoData: Data?,
        createdAt: Date = .now,
        archiveLimits: FieldnotesArchiveLimits = .version1
    ) throws -> UUID {
        let record = FieldnotesArchiveRecord(
            id: UUID(),
            createdAt: createdAt,
            text: text,
            emoji: emoji,
            photoData: photoData
        )
        try repository.persist(record) { usage in
            try FieldnotesArchiveCodec.validate(
                record,
                addingTo: usage,
                exportedAt: Date(timeIntervalSince1970: 0),
                limits: archiveLimits
            )
        }
        return record.id
    }
}

@ModelActor
actor FieldnotePersistenceStore {
    // Callers may only need confirmation that persistence completed successfully.
    // See https://www.avanderlee.com/swift/discardableresult/
    @discardableResult
    func save(
        text: String,
        emoji: String?,
        photoData: Data?,
        createdAt: Date = .now,
        archiveLimits: FieldnotesArchiveLimits = .version1
    ) throws -> UUID {
        try FieldnotePersistenceOperation(
            repository: SwiftDataFieldnotePersistenceRepository(context: modelContext)
        ).save(
            text: text,
            emoji: emoji,
            photoData: photoData,
            createdAt: createdAt,
            archiveLimits: archiveLimits
        )
    }
}

private struct SwiftDataFieldnotePersistenceRepository: FieldnotePersistenceRepository {
    let context: ModelContext

    func persist(
        _ record: FieldnotesArchiveRecord,
        validatingUsage: (FieldnotesArchiveUsage) throws -> FieldnotesArchiveUsage
    ) throws {
        try FieldnotesWriteSerialization.withLock {
            do {
                let updatedUsage = try validatingUsage(
                    FieldnotesArchiveUsageRepository.current(in: context)
                )
                let fieldnote = Fieldnote(
                    text: record.text,
                    emoji: record.emoji,
                    photoData: record.photoData,
                    createdAt: Date(timeIntervalSince1970: record.createdAtUnixSeconds)
                )
                fieldnote.id = record.id
                context.insert(fieldnote)
                try FieldnotesArchiveUsageRepository.update(updatedUsage, in: context)
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                context.rollback()
                throw error
            }
        }
    }
}
