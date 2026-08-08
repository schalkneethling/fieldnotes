import Foundation
import SwiftData
import XCTest
@testable import Fieldnotes

@MainActor
final class FieldnotePersistenceTests: XCTestCase {
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

    func testSavePersistsCompleteFieldnoteAndLeavesNoPendingChanges() async throws {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let photoData = Data([0x46, 0x49, 0x45, 0x4C, 0x44])

        let persistence = FieldnotePersistenceStore(modelContainer: container)
        let savedID = try await persistence.save(
            text: "A small, bright moment.",
            emoji: "✨",
            photoData: photoData,
            createdAt: createdAt
        )

        XCTAssertFalse(container.mainContext.hasChanges)

        let verificationContext = ModelContext(container)
        // ast-grep-ignore: unbounded-fetch-descriptor -- this one-record integration fixture verifies every persisted field.
        let fetched = try XCTUnwrap(verificationContext.fetch(FetchDescriptor<Fieldnote>()).only)

        XCTAssertEqual(fetched.id, savedID)
        XCTAssertEqual(fetched.createdAt, createdAt)
        XCTAssertEqual(fetched.text, "A small, bright moment.")
        XCTAssertEqual(fetched.emoji, "✨")
        XCTAssertEqual(fetched.photoData, photoData)
    }

    func testSavePersistsEachFieldnoteExactlyOnce() async throws {
        let persistence = FieldnotePersistenceStore(modelContainer: container)
        try await persistence.save(text: "First", emoji: nil, photoData: nil)
        try await persistence.save(text: "Second", emoji: "🙂", photoData: nil)

        let verificationContext = ModelContext(container)
        // ast-grep-ignore: unbounded-fetch-descriptor -- this integration assertion compares the complete two-record fixture.
        let fetched = try verificationContext.fetch(FetchDescriptor<Fieldnote>())

        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(Set(fetched.map(\.text)), ["First", "Second"])
        XCTAssertEqual(Set(fetched.map(\.id)).count, 2)
    }

    func testCameraCaptureSupersedesPendingLibraryPhotoBeforeSave() async throws {
        let libraryPhotoData = Data("library".utf8)
        let cameraPhotoData = Data("camera".utf8)
        var photoSelection = PhotoSelectionState()

        let pendingLibraryRequest = photoSelection.beginLibraryLoad()
        photoSelection.cancelLibraryLoad()
        photoSelection.selectCameraPhoto(cameraPhotoData)
        photoSelection.finishLibraryLoad(with: libraryPhotoData, requestID: pendingLibraryRequest)

        XCTAssertEqual(photoSelection.data, cameraPhotoData)

        let persistence = FieldnotePersistenceStore(modelContainer: container)
        try await persistence.save(
            text: "Camera won the race.",
            emoji: nil,
            photoData: photoSelection.data
        )

        let verificationContext = ModelContext(container)
        // ast-grep-ignore: unbounded-fetch-descriptor -- this one-record regression fixture verifies the selected photo bytes.
        let fetched = try XCTUnwrap(verificationContext.fetch(FetchDescriptor<Fieldnote>()).only)
        XCTAssertEqual(fetched.photoData, cameraPhotoData)
    }

    func testSavingOneFieldnoteHasConstantReadCostAtBudgetScales() throws {
        let small = try measureSaveCost(seededFieldnoteCount: 1_000)
        let large = try measureSaveCost(seededFieldnoteCount: 5_000)

        XCTAssertEqual(large.recordsRead, small.recordsRead)
        XCTAssertEqual(large.bytesDeserialized, small.bytesDeserialized)
    }

    func testConcurrentSavesKeepArchiveUsageInSync() async throws {
        let firstStore = FieldnotePersistenceStore(modelContainer: container)
        let secondStore = FieldnotePersistenceStore(modelContainer: container)

        async let firstID = firstStore.save(
            text: "First concurrent Fieldnote",
            emoji: nil,
            photoData: Data([0x01, 0x02])
        )
        async let secondID = secondStore.save(
            text: "Second concurrent Fieldnote",
            emoji: nil,
            photoData: Data([0x03, 0x04, 0x05])
        )
        _ = try await (firstID, secondID)

        let verificationContext = ModelContext(container)
        let usage = try FieldnotesArchiveUsageRepository.current(in: verificationContext)
        XCTAssertEqual(usage.fieldnoteCount, 2)
        XCTAssertEqual(usage.totalPhotoBytes, 5)
    }

    private func measureSaveCost(
        seededFieldnoteCount: Int
    ) throws -> PersistenceReadCost {
        let repository = CountingFieldnotePersistenceRepository(
            usage: FieldnotesArchiveUsage(
                fieldnoteCount: seededFieldnoteCount,
                totalPhotoBytes: 0,
                estimatedArchiveBytes: 1_024 + (seededFieldnoteCount * 1_024)
            )
        )
        try FieldnotePersistenceOperation(repository: repository).save(
            text: "One more Fieldnote",
            emoji: nil,
            photoData: Data([0x01])
        )
        return repository.readCost
    }
}

private struct PersistenceReadCost: Equatable {
    let recordsRead: Int
    let bytesDeserialized: Int
}

private final class CountingFieldnotePersistenceRepository: FieldnotePersistenceRepository {
    private let usage: FieldnotesArchiveUsage
    private(set) var recordsRead = 0
    private(set) var bytesDeserialized = 0

    var readCost: PersistenceReadCost {
        PersistenceReadCost(
            recordsRead: recordsRead,
            bytesDeserialized: bytesDeserialized
        )
    }

    init(usage: FieldnotesArchiveUsage) {
        self.usage = usage
    }

    func persist(
        _: FieldnotesArchiveRecord,
        validatingUsage: (FieldnotesArchiveUsage) throws -> FieldnotesArchiveUsage
    ) throws {
        recordsRead += 1
        bytesDeserialized += MemoryLayout<FieldnotesArchiveUsage>.size
        _ = try validatingUsage(usage)
    }
}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}
