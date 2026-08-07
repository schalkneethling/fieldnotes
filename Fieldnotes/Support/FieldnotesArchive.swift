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
        try validateEncodedSizeUpperBound(of: archive, limits: limits)
        return archive
    }

    static func encode(
        _ archive: FieldnotesArchive,
        limits: FieldnotesArchiveLimits = .version1
    ) throws -> Data {
        try validate(archive, limits: limits)
        try validateEncodedSizeUpperBound(of: archive, limits: limits)

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
        guard archive.fieldnotes.count <= limits.maximumFieldnoteCount else {
            throw FieldnotesArchiveError.tooManyFieldnotes
        }

        var identifiers: Set<UUID> = []
        var totalPhotoBytes = 0

        for fieldnote in archive.fieldnotes {
            guard identifiers.insert(fieldnote.id).inserted else {
                throw FieldnotesArchiveError.duplicateIdentifier(fieldnote.id)
            }
            guard fieldnote.createdAtUnixSeconds.isFinite else {
                throw FieldnotesArchiveError.invalidArchive
            }
            guard fieldnote.text.utf8.count <= limits.maximumTextBytes else {
                throw FieldnotesArchiveError.fieldnoteTextTooLarge
            }
            guard let photoData = fieldnote.photoData else { continue }
            guard photoData.count <= limits.maximumPhotoBytes else {
                throw FieldnotesArchiveError.fieldnotePhotoTooLarge
            }
            let (newTotal, overflow) = totalPhotoBytes.addingReportingOverflow(photoData.count)
            guard !overflow, newTotal <= limits.maximumTotalPhotoBytes else {
                throw FieldnotesArchiveError.totalPhotoDataTooLarge
            }
            totalPhotoBytes = newTotal
        }
    }

    private static func validateEncodedSizeUpperBound(
        of archive: FieldnotesArchive,
        limits: FieldnotesArchiveLimits
    ) throws {
        var estimatedBytes = 1_024
        guard estimatedBytes <= limits.maximumArchiveBytes else {
            throw FieldnotesArchiveError.archiveTooLarge
        }

        for fieldnote in archive.fieldnotes {
            try add(1_024, to: &estimatedBytes)
            try add(fieldnote.text.utf8.count * 6, to: &estimatedBytes)
            try add((fieldnote.emoji?.utf8.count ?? 0) * 6, to: &estimatedBytes)

            if let photoData = fieldnote.photoData {
                let groups = (photoData.count + 2) / 3
                try add(groups * 4, to: &estimatedBytes)
            }

            guard estimatedBytes <= limits.maximumArchiveBytes else {
                throw FieldnotesArchiveError.archiveTooLarge
            }
        }
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
            return open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
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
            let bytesRead = Darwin.read(descriptor, &buffer, min(buffer.count, remaining))
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

    func previewRestore(_ archive: FieldnotesArchive) throws -> FieldnotesRestorePreview {
        try FieldnotesArchiveCodec.validate(archive)
        modelContext.autosaveEnabled = false
        let classification = try classify(archive)
        return FieldnotesRestorePreview(
            fieldnoteCount: archive.fieldnotes.count,
            newFieldnoteCount: classification.missing.count,
            existingFieldnoteCount: classification.existingCount
        )
    }

    func restore(
        _ archive: FieldnotesArchive,
        save: ContextSaver = { try $0.save() }
    ) throws -> FieldnotesRestoreResult {
        try FieldnotesArchiveCodec.validate(archive)
        modelContext.autosaveEnabled = false
        let classification = try classify(archive)
        guard !classification.missing.isEmpty else {
            return FieldnotesRestoreResult(
                addedFieldnoteCount: 0,
                existingFieldnoteCount: classification.existingCount
            )
        }

        do {
            for record in classification.missing {
                let fieldnote = Fieldnote(
                    text: record.text,
                    emoji: record.emoji,
                    photoData: record.photoData,
                    createdAt: Date(timeIntervalSince1970: record.createdAtUnixSeconds)
                )
                fieldnote.id = record.id
                modelContext.insert(fieldnote)
            }
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

    private func classify(
        _ archive: FieldnotesArchive
    ) throws -> (missing: [FieldnotesArchiveRecord], existingCount: Int) {
        let existing = try modelContext.fetch(FetchDescriptor<Fieldnote>())
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
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

        let combinedRecords = existing.map(FieldnotesArchiveRecord.init) + missing
        _ = try FieldnotesArchiveCodec.makeArchive(
            from: combinedRecords,
            exportedAt: Date(timeIntervalSince1970: 0)
        )

        return (missing, existingCount)
    }
}
