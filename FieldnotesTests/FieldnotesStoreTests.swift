import Foundation
import SwiftData
import XCTest
@testable import Fieldnotes

@MainActor
final class FieldnotesStoreTests: XCTestCase {
    func testDefaultVersionedConfigurationUsesLegacyStoreLocation() {
        let legacyConfiguration = ModelConfiguration(for: Fieldnote.self)

        XCTAssertEqual(FieldnotesStoreFactory.defaultConfiguration.url, legacyConfiguration.url)
    }

    func testVersionedContainerReopensLegacyStoreWithoutLosingFieldnote() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = directory.appendingPathComponent("fieldnotes.store")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let legacyConfiguration = ModelConfiguration(url: storeURL)
        var legacyContainer: ModelContainer? = try ModelContainer(
            for: Fieldnote.self,
            configurations: legacyConfiguration
        )

        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let photoData = Data("legacy-photo".utf8)
        let saved = try FieldnotePersistence.save(
            text: "Still here after versioning.",
            emoji: "🌱",
            photoData: photoData,
            createdAt: createdAt,
            in: try XCTUnwrap(legacyContainer).mainContext
        )
        let savedID = saved.id
        legacyContainer = nil

        let versionedConfiguration = ModelConfiguration(
            schema: FieldnotesStoreFactory.schema,
            url: storeURL
        )
        let versionedContainer = try FieldnotesStoreFactory.makeContainer(
            configuration: versionedConfiguration
        )
        let fetched = try XCTUnwrap(
            versionedContainer.mainContext.fetch(FetchDescriptor<Fieldnote>()).only
        )

        XCTAssertEqual(fetched.id, savedID)
        XCTAssertEqual(fetched.createdAt, createdAt)
        XCTAssertEqual(fetched.text, "Still here after versioning.")
        XCTAssertEqual(fetched.emoji, "🌱")
        XCTAssertEqual(fetched.photoData, photoData)
    }

    func testStartupFailureDoesNotCreateFallbackContainer() async {
        let counter = CallCounter()
        let startup = StoreStartup {
            counter.increment()
            throw NSError(
                domain: "Private path: /var/mobile/fieldnotes.store",
                code: 42,
                userInfo: [NSLocalizedDescriptionKey: "Private path: /var/mobile/fieldnotes.store"]
            )
        }

        await startup.start()

        guard case .failed(let failure) = startup.state else {
            return XCTFail("Expected startup to fail")
        }
        XCTAssertEqual(counter.value, 1)
        XCTAssertEqual(failure.domain, "StoreOpenError")
        XCTAssertEqual(failure.code, 42)
        XCTAssertFalse(failure.diagnostics.contains("/var/mobile"))
    }

    func testRetryReusesLoaderAndCanRecover() async throws {
        let counter = CallCounter()
        let container = try ModelContainer(
            for: Fieldnote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let startup = StoreStartup {
            if counter.increment() == 1 {
                throw NSError(domain: "FieldnotesTests.Store", code: 42)
            }
            return container
        }

        await startup.start()
        guard case .failed = startup.state else {
            return XCTFail("Expected the first startup attempt to fail")
        }

        await startup.retry()

        guard case .ready(let loadedContainer) = startup.state else {
            return XCTFail("Expected retry to load the store")
        }
        XCTAssertTrue(loadedContainer === container)
        XCTAssertEqual(counter.value, 2)
    }
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    @discardableResult
    func increment() -> Int {
        lock.withLock {
            count += 1
            return count
        }
    }
}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}
