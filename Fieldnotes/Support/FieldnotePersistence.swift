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

struct SwiftDataFieldnotePersistenceRepository: FieldnotePersistenceRepository {
    let context: ModelContext
    let usageAccess: any FieldnotesArchiveUsageAccess

    init(
        context: ModelContext,
        usageAccess: (any FieldnotesArchiveUsageAccess)? = nil
    ) {
        self.context = context
        self.usageAccess = usageAccess
            ?? SwiftDataFieldnotesArchiveUsageAccess(context: context)
    }

    func persist(
        _ record: FieldnotesArchiveRecord,
        validatingUsage: (FieldnotesArchiveUsage) throws -> FieldnotesArchiveUsage
    ) throws {
        try FieldnotesWriteSerialization.withLock {
            context.autosaveEnabled = false
            do {
                let updatedUsage = try validatingUsage(
                    FieldnotesArchiveUsageRepository.current(using: usageAccess)
                )
                context.insert(Fieldnote(record: record))
                try FieldnotesArchiveUsageRepository.update(
                    updatedUsage,
                    using: usageAccess
                )
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
