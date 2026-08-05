import Foundation
import SwiftData
import XCTest
@testable import Fieldnotes

@MainActor
final class FieldnotePersistenceTests: XCTestCase {
    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Fieldnote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    override func tearDownWithError() throws {
        container = nil
    }

    func testSavePersistsCompleteFieldnoteAndLeavesNoPendingChanges() throws {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let photoData = Data([0x46, 0x49, 0x45, 0x4C, 0x44])

        let saved = try FieldnotePersistence.save(
            text: "A small, bright moment.",
            emoji: "✨",
            photoData: photoData,
            createdAt: createdAt,
            in: container.mainContext
        )

        XCTAssertFalse(container.mainContext.hasChanges)

        let verificationContext = ModelContext(container)
        let fetched = try XCTUnwrap(verificationContext.fetch(FetchDescriptor<Fieldnote>()).only)

        XCTAssertEqual(fetched.id, saved.id)
        XCTAssertEqual(fetched.createdAt, createdAt)
        XCTAssertEqual(fetched.text, "A small, bright moment.")
        XCTAssertEqual(fetched.emoji, "✨")
        XCTAssertEqual(fetched.photoData, photoData)
    }

    func testSavePersistsEachFieldnoteExactlyOnce() throws {
        try FieldnotePersistence.save(text: "First", emoji: nil, photoData: nil, in: container.mainContext)
        try FieldnotePersistence.save(text: "Second", emoji: "🙂", photoData: nil, in: container.mainContext)

        let verificationContext = ModelContext(container)
        let fetched = try verificationContext.fetch(FetchDescriptor<Fieldnote>())

        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(Set(fetched.map(\.text)), ["First", "Second"])
        XCTAssertEqual(Set(fetched.map(\.id)).count, 2)
    }

    func testCameraCaptureSupersedesPendingLibraryPhotoBeforeSave() throws {
        let libraryPhotoData = Data("library".utf8)
        let cameraPhotoData = Data("camera".utf8)
        var photoSelection = PhotoSelectionState()

        let pendingLibraryRequest = photoSelection.beginLibraryLoad()
        photoSelection.cancelLibraryLoad()
        photoSelection.selectCameraPhoto(cameraPhotoData)
        photoSelection.finishLibraryLoad(with: libraryPhotoData, requestID: pendingLibraryRequest)

        XCTAssertEqual(photoSelection.data, cameraPhotoData)

        try FieldnotePersistence.save(
            text: "Camera won the race.",
            emoji: nil,
            photoData: photoSelection.data,
            in: container.mainContext
        )

        let verificationContext = ModelContext(container)
        let fetched = try XCTUnwrap(verificationContext.fetch(FetchDescriptor<Fieldnote>()).only)
        XCTAssertEqual(fetched.photoData, cameraPhotoData)
    }
}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}
