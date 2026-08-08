import Foundation
import SwiftData
import XCTest
@testable import Fieldnotes

@MainActor
final class FieldnotesArchiveTests: XCTestCase {
    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try FieldnotesStoreFactory.makeContainer(
            configuration: ModelConfiguration(
                schema: FieldnotesStoreFactory.schema,
                isStoredInMemoryOnly: true
            )
        )
    }

    override func tearDownWithError() throws {
        container = nil
    }

    func testCodecRoundTripsEveryFieldInDeterministicOrder() throws {
        let earlierID = try XCTUnwrap(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        let laterID = try XCTUnwrap(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        let earlier = FieldnotesArchiveRecord(
            id: earlierID,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000.125),
            text: "A quiet moment 🌱",
            emoji: nil,
            photoData: Data([0x00, 0x7F, 0xFF])
        )
        let later = FieldnotesArchiveRecord(
            id: laterID,
            createdAt: Date(timeIntervalSince1970: 1_800_000_001.5),
            text: "Later",
            emoji: "✨",
            photoData: nil
        )

        let archive = try FieldnotesArchiveCodec.makeArchive(
            from: [later, earlier],
            exportedAt: Date(timeIntervalSince1970: 1_900_000_000)
        )
        let firstEncoding = try FieldnotesArchiveCodec.encode(archive)
        let secondEncoding = try FieldnotesArchiveCodec.encode(archive)
        let decoded = try FieldnotesArchiveCodec.decode(firstEncoding)

        XCTAssertEqual(firstEncoding, secondEncoding)
        XCTAssertEqual(decoded, archive)
        XCTAssertEqual(decoded.fieldnotes.map(\.id), [earlierID, laterID])
        let json = try XCTUnwrap(String(data: firstEncoding, encoding: .utf8))
        XCTAssertTrue(json.contains("\"emoji\":null"))
        XCTAssertTrue(json.contains("\"photoData\":null"))
    }

    func testDecoderRejectsUnsupportedVersionAndDuplicateIdentifiers() throws {
        let record = makeRecord(text: "Once")
        let unsupported = FieldnotesArchive(
            exportedAt: .now,
            fieldnotes: [record],
            formatVersion: FieldnotesArchive.currentFormatVersion + 1
        )
        let duplicate = FieldnotesArchive(
            exportedAt: .now,
            fieldnotes: [record, record]
        )

        XCTAssertThrowsError(try FieldnotesArchiveCodec.decode(JSONEncoder().encode(unsupported))) {
            guard case FieldnotesArchiveError.unsupportedVersion = $0 else {
                return XCTFail("Expected unsupported-version error, got \($0)")
            }
        }
        XCTAssertThrowsError(try FieldnotesArchiveCodec.decode(JSONEncoder().encode(duplicate))) {
            guard case FieldnotesArchiveError.duplicateIdentifier = $0 else {
                return XCTFail("Expected duplicate-identifier error, got \($0)")
            }
        }
    }

    func testDecoderRejectsMalformedJSON() {
        XCTAssertThrowsError(try FieldnotesArchiveCodec.decode(Data("not json".utf8))) {
            guard case FieldnotesArchiveError.invalidArchive = $0 else {
                return XCTFail("Expected invalid-archive error, got \($0)")
            }
        }
    }

    func testReaderRejectsOversizedFileBeforeLoadingIt() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: Data()))
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }

        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(FieldnotesArchiveLimits.version1.maximumArchiveBytes + 1))
        try handle.close()

        XCTAssertThrowsError(try FieldnotesArchiveCodec.read(from: url)) {
            guard case FieldnotesArchiveError.archiveTooLarge = $0 else {
                return XCTFail("Expected archive-too-large error, got \($0)")
            }
        }
    }

    func testReaderRejectsSymlinksAndGrowthAfterPreflight() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let fileURL = directory.appendingPathComponent("archive.json")
        let symlinkURL = directory.appendingPathComponent("archive-link.json")
        try Data("1234".utf8).write(to: fileURL)
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: fileURL)

        XCTAssertThrowsError(
            try FieldnotesArchiveCodec.readBoundedFile(at: symlinkURL, maximumBytes: 4)
        ) {
            guard case FieldnotesArchiveError.unsupportedFile = $0 else {
                return XCTFail("Expected unsupported-file error, got \($0)")
            }
        }

        XCTAssertThrowsError(
            try FieldnotesArchiveCodec.readBoundedFile(
                at: fileURL,
                maximumBytes: 4,
                afterPreflight: {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: Data("5".utf8))
                    try handle.close()
                }
            )
        ) {
            guard case FieldnotesArchiveError.archiveTooLarge = $0 else {
                return XCTFail("Expected archive-too-large error, got \($0)")
            }
        }
    }

    func testInterruptedSyscallsRetryAndOtherFailuresDoNot() {
        var openAttempts = 0
        let openResult: Int32 = FieldnotesArchiveCodec.retryingInterruptedSyscall {
            openAttempts += 1
            if openAttempts == 1 {
                errno = EINTR
                return -1
            }
            return 42
        }
        XCTAssertEqual(openResult, 42)
        XCTAssertEqual(openAttempts, 2)

        var readAttempts = 0
        let readResult: Int = FieldnotesArchiveCodec.retryingInterruptedSyscall {
            readAttempts += 1
            errno = EIO
            return -1
        }
        XCTAssertEqual(readResult, -1)
        XCTAssertEqual(readAttempts, 1)
    }

    func testEveryDeclaredValidationLimitIsEnforced() throws {
        let tinyLimits = FieldnotesArchiveLimits(
            maximumArchiveBytes: 4_096,
            maximumFieldnoteCount: 1,
            maximumTextBytes: 4,
            maximumPhotoBytes: 3,
            maximumTotalPhotoBytes: 3
        )
        let valid = FieldnotesArchiveRecord(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1),
            text: "four",
            emoji: nil,
            photoData: Data([1, 2, 3])
        )

        XCTAssertThrowsError(
            try FieldnotesArchiveCodec.validate(
                FieldnotesArchive(exportedAt: .now, fieldnotes: [valid], format: "wrong"),
                limits: tinyLimits
            )
        ) { guard case FieldnotesArchiveError.unsupportedFormat = $0 else { return XCTFail("Expected format error") } }
        XCTAssertThrowsError(
            try FieldnotesArchiveCodec.validate(
                FieldnotesArchive(exportedAt: Date(timeIntervalSince1970: .infinity), fieldnotes: [valid]),
                limits: tinyLimits
            )
        ) { guard case FieldnotesArchiveError.invalidArchive = $0 else { return XCTFail("Expected timestamp error") } }
        XCTAssertThrowsError(
            try FieldnotesArchiveCodec.validate(
                FieldnotesArchive(
                    exportedAt: .now,
                    fieldnotes: [makeRecord(createdAt: Date(timeIntervalSince1970: .infinity), text: "ok")]
                ),
                limits: tinyLimits
            )
        ) { guard case FieldnotesArchiveError.invalidArchive = $0 else { return XCTFail("Expected fieldnote timestamp error") } }
        XCTAssertThrowsError(
            try FieldnotesArchiveCodec.validate(
                FieldnotesArchive(exportedAt: .now, fieldnotes: [valid, makeRecord(text: "two")]),
                limits: tinyLimits
            )
        ) { guard case FieldnotesArchiveError.tooManyFieldnotes = $0 else { return XCTFail("Expected count error") } }
        XCTAssertThrowsError(
            try FieldnotesArchiveCodec.validate(
                FieldnotesArchive(exportedAt: .now, fieldnotes: [makeRecord(text: "12345")]),
                limits: tinyLimits
            )
        ) { guard case FieldnotesArchiveError.fieldnoteTextTooLarge = $0 else { return XCTFail("Expected text error") } }
        XCTAssertThrowsError(
            try FieldnotesArchiveCodec.validate(
                FieldnotesArchive(exportedAt: .now, fieldnotes: [makeRecord(text: "ok", photoData: Data(repeating: 1, count: 4))]),
                limits: tinyLimits
            )
        ) { guard case FieldnotesArchiveError.fieldnotePhotoTooLarge = $0 else { return XCTFail("Expected photo error") } }

        let totalLimits = FieldnotesArchiveLimits(
            maximumArchiveBytes: 4_096,
            maximumFieldnoteCount: 2,
            maximumTextBytes: 4,
            maximumPhotoBytes: 3,
            maximumTotalPhotoBytes: 3
        )
        XCTAssertThrowsError(
            try FieldnotesArchiveCodec.validate(
                FieldnotesArchive(
                    exportedAt: .now,
                    fieldnotes: [
                        makeRecord(text: "one", photoData: Data([1, 2])),
                        makeRecord(text: "two", photoData: Data([3, 4]))
                    ]
                ),
                limits: totalLimits
            )
        ) { guard case FieldnotesArchiveError.totalPhotoDataTooLarge = $0 else { return XCTFail("Expected total-photo error") } }

        let encodedLimit = FieldnotesArchiveLimits(
            maximumArchiveBytes: 16,
            maximumFieldnoteCount: 1,
            maximumTextBytes: 4,
            maximumPhotoBytes: 3,
            maximumTotalPhotoBytes: 3
        )
        XCTAssertThrowsError(
            try FieldnotesArchiveCodec.makeArchive(from: [], limits: encodedLimit)
        ) { guard case FieldnotesArchiveError.archiveTooLarge = $0 else { return XCTFail("Expected encoded-size error") } }
    }

    func testPersistenceRejectsAChangeThatWouldMakeTheStoreUnexportable() async throws {
        let tinyLimits = FieldnotesArchiveLimits(
            maximumArchiveBytes: 4_096,
            maximumFieldnoteCount: 2,
            maximumTextBytes: 20,
            maximumPhotoBytes: 3,
            maximumTotalPhotoBytes: 3
        )
        let persistence = FieldnotePersistenceStore(modelContainer: container)
        try await persistence.save(
            text: "First",
            emoji: nil,
            photoData: Data([1, 2]),
            archiveLimits: tinyLimits
        )

        do {
            _ = try await persistence.save(
                text: "Second",
                emoji: nil,
                photoData: Data([3, 4]),
                archiveLimits: tinyLimits
            )
            XCTFail("Expected archive capacity error")
        } catch {
            guard case FieldnotesArchiveError.totalPhotoDataTooLarge = error else {
                return XCTFail("Expected total-photo error, got \(error)")
            }
        }

        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Fieldnote>()), 1)
    }

    func testRestoreIntoEmptyStoreIsExactAndIdempotent() async throws {
        let first = makeRecord(text: "First", emoji: "🌱", photoData: Data(repeating: 0xAB, count: 1_024))
        let second = makeRecord(text: "Second", emoji: nil, photoData: nil)
        let archive = try FieldnotesArchiveCodec.makeArchive(from: [second, first])

        let archiveStore = FieldnotesArchiveStore(modelContainer: container)
        let firstResult = try await archiveStore.restore(archive)
        let secondResult = try await archiveStore.restore(archive)

        XCTAssertEqual(firstResult, FieldnotesRestoreResult(addedFieldnoteCount: 2, existingFieldnoteCount: 0))
        XCTAssertEqual(secondResult, FieldnotesRestoreResult(addedFieldnoteCount: 0, existingFieldnoteCount: 2))

        let verificationContext = ModelContext(container)
        // ast-grep-ignore: unbounded-fetch-descriptor -- this restore test compares the complete two-record fixture.
        let restored = try verificationContext.fetch(FetchDescriptor<Fieldnote>())
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(Set(restored.map(\.id)), Set([first.id, second.id]))
        XCTAssertEqual(restored.first(where: { $0.id == first.id })?.createdAt.timeIntervalSince1970, first.createdAtUnixSeconds)
        XCTAssertEqual(restored.first(where: { $0.id == first.id })?.text, first.text)
        XCTAssertEqual(restored.first(where: { $0.id == first.id })?.emoji, first.emoji)
        XCTAssertEqual(restored.first(where: { $0.id == first.id })?.photoData, first.photoData)
        let usage = try FieldnotesArchiveUsageRepository.current(in: verificationContext)
        XCTAssertEqual(usage.fieldnoteCount, 2)
        XCTAssertEqual(
            usage.totalPhotoBytes,
            (first.photoData?.count ?? 0) + (second.photoData?.count ?? 0)
        )
    }

    func testStoreExportDecodesAndRestoresIntoFreshStore() async throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000.75)
        let photoData = Data(repeating: 0x5A, count: 8_192)
        let fieldnote = Fieldnote(
            text: "Carried across stores",
            emoji: "🧭",
            photoData: photoData,
            createdAt: createdAt
        )
        fieldnote.id = id
        container.mainContext.insert(fieldnote)
        try container.mainContext.save()

        let archiveStore = FieldnotesArchiveStore(modelContainer: container)
        let records = try await archiveStore.exportRecords()
        let encoded = try FieldnotesArchiveCodec.encode(
            FieldnotesArchiveCodec.makeArchive(
                from: records,
                exportedAt: Date(timeIntervalSince1970: 1_900_000_000)
            )
        )
        let independentlyDecoded = try FieldnotesArchiveCodec.decode(encoded)
        let freshContainer = try FieldnotesStoreFactory.makeContainer(
            configuration: ModelConfiguration(
                schema: FieldnotesStoreFactory.schema,
                isStoredInMemoryOnly: true
            )
        )

        let freshArchiveStore = FieldnotesArchiveStore(modelContainer: freshContainer)
        let result = try await freshArchiveStore.restore(independentlyDecoded)

        XCTAssertEqual(result.addedFieldnoteCount, 1)
        let restored = try XCTUnwrap(
            // ast-grep-ignore: unbounded-fetch-descriptor -- this fresh-store round trip intentionally verifies its only record.
            ModelContext(freshContainer).fetch(FetchDescriptor<Fieldnote>()).only
        )
        XCTAssertEqual(restored.id, id)
        XCTAssertEqual(restored.createdAt, createdAt)
        XCTAssertEqual(restored.text, "Carried across stores")
        XCTAssertEqual(restored.emoji, "🧭")
        XCTAssertEqual(restored.photoData, photoData)
    }

    func testConflictRejectsEntireRestoreBeforeAddingMissingFieldnotes() async throws {
        let conflictingID = UUID()
        try insertFieldnote(id: conflictingID, text: "Local")
        let conflict = FieldnotesArchiveRecord(
            id: conflictingID,
            createdAt: Date(timeIntervalSince1970: 10),
            text: "Archive",
            emoji: nil,
            photoData: nil
        )
        let missing = makeRecord(text: "Must not be added")
        let archive = try FieldnotesArchiveCodec.makeArchive(from: [missing, conflict])

        let archiveStore = FieldnotesArchiveStore(modelContainer: container)
        do {
            _ = try await archiveStore.restore(archive)
            XCTFail("Expected conflict error")
        } catch {
            guard case FieldnotesArchiveError.conflictingIdentifier = error else {
                return XCTFail("Expected conflict error, got \(error)")
            }
        }

        let verificationContext = ModelContext(container)
        // ast-grep-ignore: unbounded-fetch-descriptor -- conflict verification must inspect the complete small fixture.
        let fieldnotes = try verificationContext.fetch(FetchDescriptor<Fieldnote>())
        XCTAssertEqual(fieldnotes.count, 1)
        XCTAssertEqual(fieldnotes.only?.id, conflictingID)
        XCTAssertEqual(fieldnotes.only?.text, "Local")
    }

    func testSaveFailureRollsBackEveryRestoredFieldnote() async throws {
        let archive = try FieldnotesArchiveCodec.makeArchive(
            from: [makeRecord(text: "First"), makeRecord(text: "Second")]
        )

        let archiveStore = FieldnotesArchiveStore(modelContainer: container)
        do {
            _ = try await archiveStore.restore(archive) { _ in
                throw InjectedSaveError()
            }
            XCTFail("Expected injected save error")
        } catch is InjectedSaveError {
        }

        let verificationContext = ModelContext(container)
        // ast-grep-ignore: unbounded-fetch-descriptor -- rollback verification must prove the fixture store remains empty.
        XCTAssertTrue(try verificationContext.fetch(FetchDescriptor<Fieldnote>()).isEmpty)
        XCTAssertEqual(
            try FieldnotesArchiveUsageRepository.current(in: verificationContext),
            .empty
        )
    }

    func testSameContentWithDifferentIdentifiersRemainsDistinct() async throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = FieldnotesArchiveRecord(
            id: UUID(),
            createdAt: date,
            text: "Same moment",
            emoji: "🙂",
            photoData: nil
        )
        let second = FieldnotesArchiveRecord(
            id: UUID(),
            createdAt: date,
            text: "Same moment",
            emoji: "🙂",
            photoData: nil
        )
        let archive = try FieldnotesArchiveCodec.makeArchive(from: [first, second])

        let archiveStore = FieldnotesArchiveStore(modelContainer: container)
        let result = try await archiveStore.restore(archive)

        XCTAssertEqual(result.addedFieldnoteCount, 2)
        let verificationContext = ModelContext(container)
        // ast-grep-ignore: unbounded-fetch-descriptor -- identity verification compares the complete two-record fixture.
        let restored = try verificationContext.fetch(FetchDescriptor<Fieldnote>())
        XCTAssertEqual(Set(restored.map(\.id)), Set([first.id, second.id]))
    }

    private func makeRecord(
        createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
        text: String,
        emoji: String? = nil,
        photoData: Data? = nil
    ) -> FieldnotesArchiveRecord {
        FieldnotesArchiveRecord(
            id: UUID(),
            createdAt: createdAt,
            text: text,
            emoji: emoji,
            photoData: photoData
        )
    }

    private func insertFieldnote(id: UUID, text: String) throws {
        let fieldnote = Fieldnote(
            text: text,
            createdAt: Date(timeIntervalSince1970: 10)
        )
        fieldnote.id = id
        container.mainContext.insert(fieldnote)
        try container.mainContext.save()
    }
}

private struct InjectedSaveError: Error {}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}
