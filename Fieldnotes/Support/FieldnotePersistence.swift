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

enum FieldnoteDeletionError: LocalizedError {
    case archiveUsageOutOfSync

    var errorDescription: String? {
        switch self {
        case .archiveUsageOutOfSync:
            "Fieldnotes could not verify local archive usage. Nothing was deleted."
        }
    }
}

@ModelActor
actor FieldnoteDeletionStore {
    func delete(id: UUID) throws {
        try SwiftDataFieldnoteDeletionRepository(context: modelContext).delete(id: id)
    }
}

struct SwiftDataFieldnoteDeletionRepository {
    typealias ContextSaver = (ModelContext) throws -> Void

    let context: ModelContext
    let save: ContextSaver

    init(
        context: ModelContext,
        save: @escaping ContextSaver = { try $0.save() }
    ) {
        self.context = context
        self.save = save
    }

    func delete(id: UUID) throws {
        try FieldnotesWriteSerialization.withLock {
            context.autosaveEnabled = false
            var descriptor = FetchDescriptor<Fieldnote>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1
            guard let fieldnote = try context.fetch(descriptor).first else { return }

            do {
                let updatedUsage = try usageAfterRemoving(
                    FieldnotesArchiveRecord(fieldnote: fieldnote),
                    from: FieldnotesArchiveUsageRepository.current(in: context)
                )
                context.delete(fieldnote)
                try FieldnotesArchiveUsageRepository.update(updatedUsage, in: context)
                if context.hasChanges {
                    try save(context)
                }
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    private func usageAfterRemoving(
        _ record: FieldnotesArchiveRecord,
        from usage: FieldnotesArchiveUsage
    ) throws -> FieldnotesArchiveUsage {
        let measuredRecord = try FieldnotesArchiveCodec.measure(
            record,
            addingTo: .empty
        )
        let estimatedRecordBytes = measuredRecord.estimatedArchiveBytes
            - FieldnotesArchiveUsage.empty.estimatedArchiveBytes
        let photoBytes = record.photoData?.count ?? 0

        guard usage.fieldnoteCount > 0,
              usage.totalPhotoBytes >= photoBytes,
              usage.estimatedArchiveBytes
                >= FieldnotesArchiveUsage.empty.estimatedArchiveBytes + estimatedRecordBytes else {
            throw FieldnoteDeletionError.archiveUsageOutOfSync
        }

        return FieldnotesArchiveUsage(
            fieldnoteCount: usage.fieldnoteCount - 1,
            totalPhotoBytes: usage.totalPhotoBytes - photoBytes,
            estimatedArchiveBytes: usage.estimatedArchiveBytes - estimatedRecordBytes
        )
    }
}
