import Darwin
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct FieldnotesArchive: Codable, Equatable, Sendable {
    static let formatIdentifier = "com.schalkneethling.fieldnotes.archive"
    static let currentFormatVersion = 1

    let format: String
    let formatVersion: Int
    let exportedAtUnixSeconds: TimeInterval
    let fieldnotes: [FieldnotesArchiveRecord]

    init(
        exportedAt: Date,
        fieldnotes: [FieldnotesArchiveRecord],
        format: String = Self.formatIdentifier,
        formatVersion: Int = Self.currentFormatVersion
    ) {
        self.format = format
        self.formatVersion = formatVersion
        exportedAtUnixSeconds = exportedAt.timeIntervalSince1970
        self.fieldnotes = fieldnotes
    }
}

struct FieldnotesArchiveRecord: Codable, Equatable, Sendable {
    let id: UUID
    let createdAtUnixSeconds: TimeInterval
    let text: String
    let emoji: String?
    let photoData: Data?

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAtUnixSeconds
        case text
        case emoji
        case photoData
    }

    init(fieldnote: Fieldnote) {
        id = fieldnote.id
        createdAtUnixSeconds = fieldnote.createdAt.timeIntervalSince1970
        text = fieldnote.text
        emoji = fieldnote.emoji
        photoData = fieldnote.photoData
    }

    init(id: UUID, createdAt: Date, text: String, emoji: String?, photoData: Data?) {
        self.id = id
        createdAtUnixSeconds = createdAt.timeIntervalSince1970
        self.text = text
        self.emoji = emoji
        self.photoData = photoData
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAtUnixSeconds = try container.decode(TimeInterval.self, forKey: .createdAtUnixSeconds)
        text = try container.decode(String.self, forKey: .text)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAtUnixSeconds, forKey: .createdAtUnixSeconds)
        try container.encode(text, forKey: .text)
        if let emoji {
            try container.encode(emoji, forKey: .emoji)
        } else {
            try container.encodeNil(forKey: .emoji)
        }
        if let photoData {
            try container.encode(photoData, forKey: .photoData)
        } else {
            try container.encodeNil(forKey: .photoData)
        }
    }

    func matches(_ fieldnote: Fieldnote) -> Bool {
        id == fieldnote.id
            && createdAtUnixSeconds == fieldnote.createdAt.timeIntervalSince1970
            && text == fieldnote.text
            && emoji == fieldnote.emoji
            && photoData == fieldnote.photoData
    }
}

struct FieldnotesArchiveLimits: Sendable {
    static let version1 = FieldnotesArchiveLimits(
        maximumArchiveBytes: 256 * 1_024 * 1_024,
        maximumFieldnoteCount: 10_000,
        maximumTextBytes: 1 * 1_024 * 1_024,
        maximumPhotoBytes: 32 * 1_024 * 1_024,
        maximumTotalPhotoBytes: 180 * 1_024 * 1_024
    )

    let maximumArchiveBytes: Int
    let maximumFieldnoteCount: Int
    let maximumTextBytes: Int
    let maximumPhotoBytes: Int
    let maximumTotalPhotoBytes: Int
}

struct FieldnotesArchiveUsage: Equatable, Sendable {
    static let empty = FieldnotesArchiveUsage(
        fieldnoteCount: 0,
        totalPhotoBytes: 0,
        estimatedArchiveBytes: 1_024
    )

    let fieldnoteCount: Int
    let totalPhotoBytes: Int
    let estimatedArchiveBytes: Int
}

enum FieldnotesArchiveError: LocalizedError {
    case archiveTooLarge
    case unsupportedFile
    case unsupportedFormat
    case unsupportedVersion(Int)
    case invalidArchive
    case tooManyFieldnotes
    case fieldnoteTextTooLarge
    case fieldnotePhotoTooLarge
    case totalPhotoDataTooLarge
    case duplicateIdentifier(UUID)
    case conflictingIdentifier(UUID)
    case missingLocalUsageData
    case importRequiresValidatedReader

    var errorDescription: String? {
        switch self {
        case .archiveTooLarge:
            "This archive is too large for Fieldnotes to restore safely."
        case .unsupportedFile:
            "Choose a regular Fieldnotes JSON archive file."
        case .unsupportedFormat, .invalidArchive:
            "This file is not a valid Fieldnotes archive."
        case .unsupportedVersion(let version):
            "This archive uses unsupported format version \(version)."
        case .tooManyFieldnotes:
            "This archive contains too many Fieldnotes to restore safely."
        case .fieldnoteTextTooLarge:
            "A Fieldnote in this archive contains too much text."
        case .fieldnotePhotoTooLarge:
            "A photo in this archive is too large to restore safely."
        case .totalPhotoDataTooLarge:
            "The photos in this archive are too large to restore safely."
        case .duplicateIdentifier:
            "This archive contains the same Fieldnote more than once."
        case .conflictingIdentifier:
            "A Fieldnote in this archive conflicts with a different Fieldnote already on this device. Nothing was restored."
        case .missingLocalUsageData:
            "Fieldnotes could not verify local archive usage. Nothing was changed."
        case .importRequiresValidatedReader:
            "Fieldnotes archives must be imported through the validated restore flow."
        }
    }
}

enum FieldnotesArchiveCodec {
    static func makeArchive(
        from records: [FieldnotesArchiveRecord],
        exportedAt: Date = .now,
        limits: FieldnotesArchiveLimits = .version1
    ) throws -> FieldnotesArchive {
        let sortedRecords = records.sorted {
            if $0.createdAtUnixSeconds == $1.createdAtUnixSeconds {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.createdAtUnixSeconds < $1.createdAtUnixSeconds
        }
        let archive = FieldnotesArchive(exportedAt: exportedAt, fieldnotes: sortedRecords)
        try validate(archive, limits: limits)
        return archive
    }

    static func encode(
        _ archive: FieldnotesArchive,
        limits: FieldnotesArchiveLimits = .version1
    ) throws -> Data {
        try validate(archive, limits: limits)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(archive)
        guard data.count <= limits.maximumArchiveBytes else {
            throw FieldnotesArchiveError.archiveTooLarge
        }
        return data
    }

    static func decode(
        _ data: Data,
        limits: FieldnotesArchiveLimits = .version1
    ) throws -> FieldnotesArchive {
        guard data.count <= limits.maximumArchiveBytes else {
            throw FieldnotesArchiveError.archiveTooLarge
        }

        do {
            let archive = try JSONDecoder().decode(FieldnotesArchive.self, from: data)
            try validate(archive, limits: limits)
            return archive
        } catch let error as FieldnotesArchiveError {
            throw error
        } catch {
            throw FieldnotesArchiveError.invalidArchive
        }
    }

    static func read(
        from url: URL,
        limits: FieldnotesArchiveLimits = .version1
    ) throws -> FieldnotesArchive {
        let data = try readBoundedFile(at: url, maximumBytes: limits.maximumArchiveBytes)
        return try decode(data, limits: limits)
    }

    static func validate(
        _ archive: FieldnotesArchive,
        limits: FieldnotesArchiveLimits = .version1
    ) throws {
        guard archive.format == FieldnotesArchive.formatIdentifier else {
            throw FieldnotesArchiveError.unsupportedFormat
        }
        guard archive.formatVersion == FieldnotesArchive.currentFormatVersion else {
            throw FieldnotesArchiveError.unsupportedVersion(archive.formatVersion)
        }
        guard archive.exportedAtUnixSeconds.isFinite else {
            throw FieldnotesArchiveError.invalidArchive
        }
        var identifiers: Set<UUID> = []
        var usage = FieldnotesArchiveUsage.empty
        guard usage.estimatedArchiveBytes <= limits.maximumArchiveBytes else {
            throw FieldnotesArchiveError.archiveTooLarge
        }

        for fieldnote in archive.fieldnotes {
            guard identifiers.insert(fieldnote.id).inserted else {
                throw FieldnotesArchiveError.duplicateIdentifier(fieldnote.id)
            }
            usage = try validate(fieldnote, addingTo: usage, limits: limits)
        }
    }

    static func validate(
        _ record: FieldnotesArchiveRecord,
        addingTo usage: FieldnotesArchiveUsage,
        exportedAt: Date = .now,
        limits: FieldnotesArchiveLimits
    ) throws -> FieldnotesArchiveUsage {
        guard exportedAt.timeIntervalSince1970.isFinite else {
            throw FieldnotesArchiveError.invalidArchive
        }
        guard record.createdAtUnixSeconds.isFinite else {
            throw FieldnotesArchiveError.invalidArchive
        }
        guard record.text.utf8.count <= limits.maximumTextBytes else {
            throw FieldnotesArchiveError.fieldnoteTextTooLarge
        }
        guard (record.photoData?.count ?? 0) <= limits.maximumPhotoBytes else {
            throw FieldnotesArchiveError.fieldnotePhotoTooLarge
        }

        let updatedUsage = try measure(record, addingTo: usage)
        guard updatedUsage.fieldnoteCount <= limits.maximumFieldnoteCount else {
            throw FieldnotesArchiveError.tooManyFieldnotes
        }
        guard updatedUsage.totalPhotoBytes <= limits.maximumTotalPhotoBytes else {
            throw FieldnotesArchiveError.totalPhotoDataTooLarge
        }
        guard updatedUsage.estimatedArchiveBytes <= limits.maximumArchiveBytes else {
            throw FieldnotesArchiveError.archiveTooLarge
        }
        return updatedUsage
    }

    static func measure(
        _ record: FieldnotesArchiveRecord,
        addingTo usage: FieldnotesArchiveUsage
    ) throws -> FieldnotesArchiveUsage {
        let (fieldnoteCount, countOverflow) = usage.fieldnoteCount.addingReportingOverflow(1)
        guard !countOverflow else {
            throw FieldnotesArchiveError.tooManyFieldnotes
        }

        let (totalPhotoBytes, photoOverflow) = usage.totalPhotoBytes.addingReportingOverflow(
            record.photoData?.count ?? 0
        )
        guard !photoOverflow else {
            throw FieldnotesArchiveError.totalPhotoDataTooLarge
        }

        var estimatedArchiveBytes = usage.estimatedArchiveBytes
        try add(1_024, to: &estimatedArchiveBytes)
        try add(record.text.utf8.count * 6, to: &estimatedArchiveBytes)
        try add((record.emoji?.utf8.count ?? 0) * 6, to: &estimatedArchiveBytes)

        if let photoData = record.photoData {
            let groups = (photoData.count + 2) / 3
            try add(groups * 4, to: &estimatedArchiveBytes)
        }

        return FieldnotesArchiveUsage(
            fieldnoteCount: fieldnoteCount,
            totalPhotoBytes: totalPhotoBytes,
            estimatedArchiveBytes: estimatedArchiveBytes
        )
    }

    private static func add(_ bytes: Int, to total: inout Int) throws {
        let (newTotal, overflow) = total.addingReportingOverflow(bytes)
        guard !overflow else { throw FieldnotesArchiveError.archiveTooLarge }
        total = newTotal
    }

    static func readBoundedFile(
        at url: URL,
        maximumBytes: Int,
        afterPreflight: (() throws -> Void)? = nil
    ) throws -> Data {
        let descriptor = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return retryingInterruptedSyscall {
                open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
            }
        }
        guard descriptor >= 0 else {
            throw FieldnotesArchiveError.unsupportedFile
        }
        defer { close(descriptor) }

        var initialStatus = stat()
        guard fstat(descriptor, &initialStatus) == 0,
              (initialStatus.st_mode & S_IFMT) == S_IFREG else {
            throw FieldnotesArchiveError.unsupportedFile
        }
        guard initialStatus.st_size >= 0,
              initialStatus.st_size <= maximumBytes else {
            throw FieldnotesArchiveError.archiveTooLarge
        }

        try afterPreflight?()

        var data = Data()
        data.reserveCapacity(Int(initialStatus.st_size))
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)

        while true {
            let remaining = maximumBytes + 1 - data.count
            guard remaining > 0 else {
                throw FieldnotesArchiveError.archiveTooLarge
            }
            let bytesRead: Int = retryingInterruptedSyscall {
                Darwin.read(descriptor, &buffer, min(buffer.count, remaining))
            }
            guard bytesRead >= 0 else {
                throw FieldnotesArchiveError.invalidArchive
            }
            guard bytesRead > 0 else { break }
            data.append(buffer, count: bytesRead)
        }

        var finalStatus = stat()
        guard fstat(descriptor, &finalStatus) == 0,
              finalStatus.st_size == data.count,
              data.count <= maximumBytes else {
            throw data.count > maximumBytes
                ? FieldnotesArchiveError.archiveTooLarge
                : FieldnotesArchiveError.invalidArchive
        }
        return data
    }

    static func retryingInterruptedSyscall<Result: FixedWidthInteger & SignedInteger>(
        _ operation: () -> Result
    ) -> Result {
        var result: Result
        repeat {
            result = operation()
        } while result == -1 && errno == EINTR
        return result
    }
}

struct FieldnotesArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        throw FieldnotesArchiveError.importRequiresValidatedReader
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct FieldnotesRestorePreview: Equatable, Sendable {
    let fieldnoteCount: Int
    let newFieldnoteCount: Int
    let existingFieldnoteCount: Int
}

struct FieldnotesRestoreResult: Equatable, Sendable {
    let addedFieldnoteCount: Int
    let existingFieldnoteCount: Int
}

enum FieldnotesWriteSerialization {
    private static let lock = NSLock()

    static func withLock<Result>(_ operation: () throws -> Result) rethrows -> Result {
        try lock.withLock(operation)
    }
}

protocol FieldnotesArchiveUsageAccess {
    func fetchUsageModel(key: String) throws -> FieldnotesArchiveUsageModel?
    func fetchFieldnoteCount() throws -> Int
    func enumerateFieldnotes(_ body: (Fieldnote) throws -> Void) throws
    func insertUsageModel(_ model: FieldnotesArchiveUsageModel)
    func save() throws
}

struct SwiftDataFieldnotesArchiveUsageAccess: FieldnotesArchiveUsageAccess {
    let context: ModelContext

    func fetchUsageModel(key: String) throws -> FieldnotesArchiveUsageModel? {
        var descriptor = FetchDescriptor<FieldnotesArchiveUsageModel>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchFieldnoteCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<Fieldnote>())
    }

    func enumerateFieldnotes(_ body: (Fieldnote) throws -> Void) throws {
        var descriptor = FetchDescriptor<Fieldnote>()
        descriptor.propertiesToFetch = [
            \Fieldnote.id,
            \Fieldnote.createdAt,
            \Fieldnote.text,
            \Fieldnote.emoji,
            \Fieldnote.photoData
        ]
        try context.enumerate(descriptor, batchSize: 100, block: body)
    }

    func insertUsageModel(_ model: FieldnotesArchiveUsageModel) {
        context.insert(model)
    }

    func save() throws {
        try context.save()
    }
}

enum FieldnotesArchiveUsageRepository {
    private static let singletonKey = "version-1"

    static func ensurePresent(in context: ModelContext) throws {
        try ensurePresent(using: SwiftDataFieldnotesArchiveUsageAccess(context: context))
    }

    static func ensurePresent(using access: any FieldnotesArchiveUsageAccess) throws {
        guard try model(using: access) == nil else { return }
        guard try access.fetchFieldnoteCount() > 0 else {
            let usage = FieldnotesArchiveUsage.empty
            access.insertUsageModel(
                FieldnotesArchiveUsageModel(
                    key: singletonKey,
                    totalPhotoBytes: usage.totalPhotoBytes,
                    estimatedArchiveBytes: usage.estimatedArchiveBytes
                )
            )
            try access.save()
            return
        }
        try reconcile(using: access)
    }

    static func current(in context: ModelContext) throws -> FieldnotesArchiveUsage {
        try current(using: SwiftDataFieldnotesArchiveUsageAccess(context: context))
    }

    static func current(
        using access: any FieldnotesArchiveUsageAccess
    ) throws -> FieldnotesArchiveUsage {
        let storedUsage: FieldnotesArchiveUsageModel
        if let existing = try model(using: access) {
            storedUsage = existing
        } else {
            try ensurePresent(using: access)
            storedUsage = try requiredModel(using: access)
        }
        let fieldnoteCount = try access.fetchFieldnoteCount()
        return FieldnotesArchiveUsage(
            fieldnoteCount: fieldnoteCount,
            totalPhotoBytes: storedUsage.totalPhotoBytes,
            estimatedArchiveBytes: storedUsage.estimatedArchiveBytes
        )
    }

    static func update(
        _ usage: FieldnotesArchiveUsage,
        in context: ModelContext
    ) throws {
        try update(
            usage,
            using: SwiftDataFieldnotesArchiveUsageAccess(context: context)
        )
    }

    static func update(
        _ usage: FieldnotesArchiveUsage,
        using access: any FieldnotesArchiveUsageAccess
    ) throws {
        try ensurePresent(using: access)
        let storedUsage = try requiredModel(using: access)
        storedUsage.totalPhotoBytes = usage.totalPhotoBytes
        storedUsage.estimatedArchiveBytes = usage.estimatedArchiveBytes
    }

    static func reconcile(in context: ModelContext) throws {
        try reconcile(using: SwiftDataFieldnotesArchiveUsageAccess(context: context))
    }

    static func reconcile(using access: any FieldnotesArchiveUsageAccess) throws {
        var usage = FieldnotesArchiveUsage.empty
        try access.enumerateFieldnotes { fieldnote in
            usage = try FieldnotesArchiveCodec.measure(
                FieldnotesArchiveRecord(fieldnote: fieldnote),
                addingTo: usage
            )
        }

        if let storedUsage = try model(using: access) {
            storedUsage.totalPhotoBytes = usage.totalPhotoBytes
            storedUsage.estimatedArchiveBytes = usage.estimatedArchiveBytes
        } else {
            access.insertUsageModel(
                FieldnotesArchiveUsageModel(
                    key: singletonKey,
                    totalPhotoBytes: usage.totalPhotoBytes,
                    estimatedArchiveBytes: usage.estimatedArchiveBytes
                )
            )
        }
        try access.save()
    }

    private static func requiredModel(
        using access: any FieldnotesArchiveUsageAccess
    ) throws -> FieldnotesArchiveUsageModel {
        guard let model = try model(using: access) else {
            throw FieldnotesArchiveError.missingLocalUsageData
        }
        return model
    }

    private static func model(
        using access: any FieldnotesArchiveUsageAccess
    ) throws -> FieldnotesArchiveUsageModel? {
        try access.fetchUsageModel(key: singletonKey)
    }
}

@ModelActor
actor FieldnotesArchiveStore {
    typealias ContextSaver = @Sendable (ModelContext) throws -> Void

    func exportRecords() throws -> [FieldnotesArchiveRecord] {
        let descriptor = FetchDescriptor<Fieldnote>(
            sortBy: [
                SortDescriptor(\Fieldnote.createdAt),
                SortDescriptor(\Fieldnote.id)
            ]
        )
        return try modelContext.fetch(descriptor).map(FieldnotesArchiveRecord.init)
    }

    func previewRestore(
        _ archive: FieldnotesArchive,
        limits: FieldnotesArchiveLimits = .version1
    ) throws -> FieldnotesRestorePreview {
        try FieldnotesArchiveCodec.validate(archive, limits: limits)
        modelContext.autosaveEnabled = false
        let classification = try classify(archive, limits: limits)
        return FieldnotesRestorePreview(
            fieldnoteCount: archive.fieldnotes.count,
            newFieldnoteCount: classification.missing.count,
            existingFieldnoteCount: classification.existingCount
        )
    }

    func restore(
        _ archive: FieldnotesArchive,
        limits: FieldnotesArchiveLimits = .version1,
        save: ContextSaver = { try $0.save() }
    ) throws -> FieldnotesRestoreResult {
        try FieldnotesArchiveCodec.validate(archive, limits: limits)
        return try FieldnotesWriteSerialization.withLock {
            modelContext.autosaveEnabled = false
            let classification = try classify(archive, limits: limits)
            guard !classification.missing.isEmpty else {
                return FieldnotesRestoreResult(
                    addedFieldnoteCount: 0,
                    existingFieldnoteCount: classification.existingCount
                )
            }

            do {
                for record in classification.missing {
                    modelContext.insert(Fieldnote(record: record))
                }
                try FieldnotesArchiveUsageRepository.update(
                    classification.updatedUsage,
                    in: modelContext
                )
                try save(modelContext)
            } catch {
                modelContext.rollback()
                throw error
            }

            return FieldnotesRestoreResult(
                addedFieldnoteCount: classification.missing.count,
                existingFieldnoteCount: classification.existingCount
            )
        }
    }

    private func classify(
        _ archive: FieldnotesArchive,
        limits: FieldnotesArchiveLimits
    ) throws -> (
        missing: [FieldnotesArchiveRecord],
        existingCount: Int,
        updatedUsage: FieldnotesArchiveUsage
    ) {
        // ast-grep-ignore: unbounded-fetch-descriptor -- restore compares archive IDs against the complete local collection deliberately.
        let existing = try modelContext.fetch(FetchDescriptor<Fieldnote>())
        var existingByID: [UUID: Fieldnote] = [:]
        for fieldnote in existing where existingByID[fieldnote.id] == nil {
            existingByID[fieldnote.id] = fieldnote
        }
        var missing: [FieldnotesArchiveRecord] = []
        var existingCount = 0

        for record in archive.fieldnotes {
            guard let localFieldnote = existingByID[record.id] else {
                missing.append(record)
                continue
            }
            guard record.matches(localFieldnote) else {
                throw FieldnotesArchiveError.conflictingIdentifier(record.id)
            }
            existingCount += 1
        }

        var updatedUsage = try FieldnotesArchiveUsageRepository.current(in: modelContext)
        for record in missing {
            updatedUsage = try FieldnotesArchiveCodec.validate(
                record,
                addingTo: updatedUsage,
                exportedAt: Date(timeIntervalSince1970: 0),
                limits: limits
            )
        }

        return (missing, existingCount, updatedUsage)
    }
}
