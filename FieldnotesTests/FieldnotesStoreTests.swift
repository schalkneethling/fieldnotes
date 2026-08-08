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

    func testV1SchemaShapeIsFrozen() throws {
        let schema = Schema(versionedSchema: FieldnotesSchemaV1.self)
        let entity = try XCTUnwrap(schema.entities.only)
        let attributes = entity.attributesByName
        let id = try XCTUnwrap(attributes["id"])
        let photo = try XCTUnwrap(attributes["photoData"])

        XCTAssertEqual(schema.version, Schema.Version(1, 0, 0))
        XCTAssertEqual(entity.name, "Fieldnote")
        XCTAssertEqual(
            attributes.mapValues { String(reflecting: $0.valueType) },
            [
                "id": "Foundation.UUID",
                "createdAt": "Foundation.Date",
                "text": "Swift.String",
                "emoji": "Swift.Optional<Swift.String>",
                "photoData": "Swift.Optional<Foundation.Data>"
            ]
        )
        XCTAssertFalse(id.isOptional)
        XCTAssertFalse(try XCTUnwrap(attributes["createdAt"]).isOptional)
        XCTAssertFalse(try XCTUnwrap(attributes["text"]).isOptional)
        XCTAssertTrue(try XCTUnwrap(attributes["emoji"]).isOptional)
        XCTAssertTrue(photo.isOptional)
        XCTAssertTrue(id.isUnique)
        XCTAssertTrue(photo.options.contains(.externalStorage))
        XCTAssertTrue(entity.relationships.isEmpty)
    }

    func testV2SchemaShapeIsFrozen() throws {
        let schema = Schema(versionedSchema: FieldnotesSchemaV2.self)
        let entities = Dictionary(uniqueKeysWithValues: schema.entities.map { ($0.name, $0) })
        let fieldnote = try XCTUnwrap(entities["Fieldnote"])
        let fieldnoteAttributes = fieldnote.attributesByName
        let usage = try XCTUnwrap(entities["ArchiveUsage"])
        let usageAttributes = usage.attributesByName

        XCTAssertEqual(schema.version, Schema.Version(2, 0, 0))
        XCTAssertEqual(Set(entities.keys), ["Fieldnote", "ArchiveUsage"])
        XCTAssertEqual(
            fieldnoteAttributes.mapValues { String(reflecting: $0.valueType) },
            [
                "id": "Foundation.UUID",
                "createdAt": "Foundation.Date",
                "text": "Swift.String",
                "emoji": "Swift.Optional<Swift.String>",
                "photoData": "Swift.Optional<Foundation.Data>"
            ]
        )
        XCTAssertTrue(try XCTUnwrap(fieldnoteAttributes["id"]).isUnique)
        XCTAssertTrue(try XCTUnwrap(fieldnoteAttributes["photoData"]).options.contains(.externalStorage))
        XCTAssertTrue(fieldnote.relationships.isEmpty)
        XCTAssertEqual(
            usageAttributes.mapValues { String(reflecting: $0.valueType) },
            [
                "key": "Swift.String",
                "totalPhotoBytes": "Swift.Int",
                "estimatedArchiveBytes": "Swift.Int"
            ]
        )
        XCTAssertTrue(try XCTUnwrap(usageAttributes["key"]).isUnique)
        XCTAssertTrue(usageAttributes.values.allSatisfy { !$0.isOptional })
        XCTAssertTrue(usage.relationships.isEmpty)
    }

    func testVersionedContainerReopensCheckedInPreVersioningStore() throws {
        let fixtureDirectory = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "PreVersioningStore", withExtension: nil)
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.copyItem(at: fixtureDirectory, to: directory)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let storeURL = directory.appendingPathComponent("fieldnotes.store")
        let versionedConfiguration = ModelConfiguration(
            schema: FieldnotesStoreFactory.schema,
            url: storeURL
        )
        let versionedContainer = try FieldnotesStoreFactory.makeContainer(
            configuration: versionedConfiguration
        )
        let fetched = try XCTUnwrap(
            // ast-grep-ignore: unbounded-fetch-descriptor -- the migration fixture intentionally verifies its complete one-record store.
            versionedContainer.mainContext.fetch(FetchDescriptor<Fieldnote>()).only
        )

        XCTAssertEqual(fetched.id, UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        XCTAssertEqual(fetched.createdAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(fetched.text, "Still here after versioning.")
        XCTAssertEqual(fetched.emoji, "🌱")
        XCTAssertEqual(fetched.photoData, Data(repeating: 0xAB, count: 262_144))

        let usage = try FieldnotesArchiveUsageRepository.current(
            in: versionedContainer.mainContext
        )
        XCTAssertEqual(usage.fieldnoteCount, 1)
        XCTAssertEqual(usage.totalPhotoBytes, 262_144)
        XCTAssertGreaterThan(usage.estimatedArchiveBytes, usage.totalPhotoBytes)
        XCTAssertLessThan(usage.estimatedArchiveBytes, 1 * 1_024 * 1_024)
    }

    func testUsageUpdateCreatesMissingLocalUsageRow() throws {
        let configuration = ModelConfiguration(
            schema: FieldnotesStoreFactory.schema,
            isStoredInMemoryOnly: true
        )
        let rawContainer = try ModelContainer(
            for: FieldnotesStoreFactory.schema,
            configurations: [configuration]
        )
        let context = ModelContext(rawContainer)
        context.autosaveEnabled = false
        let expected = FieldnotesArchiveUsage(
            fieldnoteCount: 0,
            totalPhotoBytes: 2,
            estimatedArchiveBytes: 2_048
        )

        try FieldnotesArchiveUsageRepository.update(expected, in: context)
        try context.save()

        XCTAssertEqual(
            try FieldnotesArchiveUsageRepository.current(in: context),
            expected
        )
    }

    func testDiagnosticsPreserveSafeUnderlyingCodesAndRedactPrivateDetails() {
        let privateError = NSError(
            domain: "Private path: /var/mobile/fieldnotes.store",
            code: 99,
            userInfo: [NSLocalizedDescriptionKey: "A private Fieldnote value"]
        )
        let posixError = NSError(
            domain: NSPOSIXErrorDomain,
            code: 28,
            userInfo: [NSUnderlyingErrorKey: privateError]
        )
        let cocoaError = NSError(
            domain: NSCocoaErrorDomain,
            code: 134_110,
            userInfo: [NSUnderlyingErrorKey: posixError]
        )
        let swiftDataError = NSError(
            domain: "SwiftData.SwiftDataError",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: cocoaError]
        )

        let failure = StoreStartupFailure(error: swiftDataError, reference: "ABC12345")

        XCTAssertEqual(
            failure.errorCodes,
            [
                StoreErrorCode(domain: "SwiftData.SwiftDataError", code: 1),
                StoreErrorCode(domain: NSCocoaErrorDomain, code: 134_110),
                StoreErrorCode(domain: NSPOSIXErrorDomain, code: 28),
                StoreErrorCode(domain: "StoreOpenError", code: 99)
            ]
        )
        XCTAssertTrue(failure.diagnostics.contains("Cause 3: StoreOpenError (99)"))
        XCTAssertFalse(failure.diagnostics.contains("/var/mobile"))
        XCTAssertFalse(failure.diagnostics.contains("private Fieldnote"))
    }

    func testStartupFailureDoesNotCreateFallbackContainer() async throws {
        let counter = CallCounter()
        let reports = FailureReportRecorder()
        let startup = StoreStartup(
            reference: "ABC12345",
            loadContainer: {
                counter.increment()
                throw PrivateMarkerError()
            },
            reportFailure: reports.record
        )

        startup.start()
        try await waitUntil { startup.state.isRetryableFailure }

        guard case .failed(let failure, retryAvailability: .available) = startup.state else {
            return XCTFail("Expected startup to fail")
        }
        XCTAssertEqual(counter.value, 1)
        XCTAssertEqual(failure.reference, "ABC12345")
        XCTAssertEqual(reports.references, ["ABC12345"])
        let report = try XCTUnwrap(reports.entries.only)
        XCTAssertEqual(report.safeDetails, failure.diagnostics)
        XCTAssertFalse(report.safeDetails.contains("SECRET_ROOT_CAUSE"))
        XCTAssertTrue(report.privateDetails.contains("SECRET_ROOT_CAUSE"))
    }

    func testRetryReusesLoaderAndCanRecover() async throws {
        let counter = CallCounter()
        let container = try FieldnotesStoreFactory.makeContainer(
            configuration: ModelConfiguration(
                schema: FieldnotesStoreFactory.schema,
                isStoredInMemoryOnly: true
            )
        )
        let startup = StoreStartup(
            loadContainer: {
                if counter.increment() == 1 {
                    throw NSError(domain: "SwiftData.SwiftDataError", code: 1)
                }
                return container
            }
        )

        startup.start()
        try await waitUntil { startup.state.isRetryableFailure }
        guard case .failed = startup.state else {
            return XCTFail("Expected the first startup attempt to fail")
        }

        startup.retry()
        try await waitUntil { startup.state.isReady }

        guard case .ready(let loadedContainer) = startup.state else {
            return XCTFail("Expected retry to load the store")
        }
        XCTAssertTrue(loadedContainer === container)
        XCTAssertEqual(counter.value, 2)
    }

    func testConsecutiveFailuresKeepReferenceAndResetPresentationIdentity() async throws {
        let reports = FailureReportRecorder()
        let startup = StoreStartup(
            reference: "ABC12345",
            loadContainer: {
                throw NSError(domain: "SwiftData.SwiftDataError", code: 1)
            },
            reportFailure: reports.record
        )

        startup.start()
        try await waitUntil { startup.state.isRetryableFailure }
        guard case .failed(let firstFailure, _) = startup.state else {
            return XCTFail("Expected the first startup attempt to fail")
        }

        startup.retry()
        try await waitUntil {
            guard case .failed(let failure, retryAvailability: .available) = startup.state else {
                return false
            }
            return failure.presentationID != firstFailure.presentationID
        }
        guard case .failed(let secondFailure, _) = startup.state else {
            return XCTFail("Expected the retry to fail")
        }

        XCTAssertEqual(firstFailure.reference, "ABC12345")
        XCTAssertEqual(secondFailure.reference, "ABC12345")
        XCTAssertNotEqual(firstFailure.presentationID, secondFailure.presentationID)
        XCTAssertEqual(reports.references, ["ABC12345", "ABC12345"])
    }

    func testTimeoutShowsRecoveryWithoutStartingOverlappingOpen() async throws {
        let timeout = TimeoutTrigger()
        let started = expectation(description: "Store open started")
        let container = try FieldnotesStoreFactory.makeContainer(
            configuration: ModelConfiguration(
                schema: FieldnotesStoreFactory.schema,
                isStoredInMemoryOnly: true
            )
        )
        let loader = BlockingFirstLoader(
            started: started,
            firstResult: .failure(NSError(domain: "SwiftData.SwiftDataError", code: 1)),
            eventualContainer: container
        )
        addTeardownBlock {
            loader.releaseFirstAttempt()
        }
        let startup = StoreStartup(
            reference: "ABC12345",
            loadContainer: { try loader.load() },
            waitForTimeout: { await timeout.wait() }
        )

        startup.start()
        await fulfillment(of: [started], timeout: 2)
        timeout.fire()
        try await waitUntil { startup.state.isWaitingFailure }

        startup.retry()
        XCTAssertEqual(loader.callCount, 1)

        loader.releaseFirstAttempt()
        try await waitUntil { startup.state.isRetryableFailure }
        startup.retry()
        try await waitUntil { startup.state.isReady }

        XCTAssertEqual(loader.callCount, 2)
    }

    func testTimedOutOriginalOpenCanStillCompleteSuccessfully() async throws {
        let timeout = TimeoutTrigger()
        let started = expectation(description: "Store open started")
        let container = try FieldnotesStoreFactory.makeContainer(
            configuration: ModelConfiguration(
                schema: FieldnotesStoreFactory.schema,
                isStoredInMemoryOnly: true
            )
        )
        let loader = BlockingFirstLoader(
            started: started,
            firstResult: .success(container),
            eventualContainer: container
        )
        addTeardownBlock {
            loader.releaseFirstAttempt()
        }
        let startup = StoreStartup(
            loadContainer: { try loader.load() },
            waitForTimeout: { await timeout.wait() }
        )

        startup.start()
        await fulfillment(of: [started], timeout: 2)
        timeout.fire()
        try await waitUntil { startup.state.isWaitingFailure }

        startup.retry()
        XCTAssertEqual(loader.callCount, 1)

        loader.releaseFirstAttempt()
        try await waitUntil { startup.state.isReady }

        XCTAssertEqual(loader.callCount, 1)
    }

    func testStaleTimeoutCannotReplaceReadyState() async throws {
        let timeout = TimeoutTrigger()
        let timeoutHandled = expectation(description: "Timeout handler completed")
        let container = try FieldnotesStoreFactory.makeContainer(
            configuration: ModelConfiguration(
                schema: FieldnotesStoreFactory.schema,
                isStoredInMemoryOnly: true
            )
        )
        let startup = StoreStartup(
            loadContainer: { container },
            waitForTimeout: {
                await timeout.wait()
                timeoutHandled.fulfill()
            }
        )

        startup.start()
        try await waitUntil { startup.state.isReady }
        timeout.fire()
        await fulfillment(of: [timeoutHandled], timeout: 2)

        XCTAssertTrue(startup.state.isReady)
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !condition() {
            guard clock.now < deadline else {
                XCTFail("Timed out waiting for startup state", file: file, line: line)
                throw TestWaitError.timedOut
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private enum TestWaitError: Error {
    case timedOut
}

private struct PrivateMarkerError: Error, CustomDebugStringConvertible {
    var debugDescription: String {
        "SECRET_ROOT_CAUSE"
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

private final class FailureReportRecorder: @unchecked Sendable {
    struct Entry {
        let reference: String
        let safeDetails: String
        let privateDetails: String
    }

    private let lock = NSLock()
    private var recordedEntries: [Entry] = []

    var entries: [Entry] {
        lock.withLock { recordedEntries }
    }

    var references: [String] {
        entries.map(\.reference)
    }

    func record(reference: String, safeDetails: String, privateDetails: String) {
        lock.withLock {
            recordedEntries.append(
                Entry(
                    reference: reference,
                    safeDetails: safeDetails,
                    privateDetails: privateDetails
                )
            )
        }
    }
}

private final class BlockingFirstLoader: @unchecked Sendable {
    private let counter = CallCounter()
    private let firstAttemptRelease = DispatchSemaphore(value: 0)
    private let started: XCTestExpectation
    private let firstResult: Result<ModelContainer, any Error>
    private let eventualContainer: ModelContainer

    init(
        started: XCTestExpectation,
        firstResult: Result<ModelContainer, any Error>,
        eventualContainer: ModelContainer
    ) {
        self.started = started
        self.firstResult = firstResult
        self.eventualContainer = eventualContainer
    }

    var callCount: Int {
        counter.value
    }

    func load() throws -> ModelContainer {
        if counter.increment() == 1 {
            started.fulfill()
            firstAttemptRelease.wait()
            return try firstResult.get()
        }

        return eventualContainer
    }

    func releaseFirstAttempt() {
        firstAttemptRelease.signal()
    }
}

private final class TimeoutTrigger: @unchecked Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        let stream = AsyncStream<Void>.makeStream()
        self.stream = stream.stream
        continuation = stream.continuation
    }

    func wait() async {
        for await _ in stream {
            return
        }
    }

    func fire() {
        continuation.yield()
    }

    deinit {
        continuation.finish()
    }
}

@MainActor
private extension StoreStartup.State {
    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var isRetryableFailure: Bool {
        if case .failed(_, retryAvailability: .available) = self { return true }
        return false
    }

    var isWaitingFailure: Bool {
        if case .failed(_, retryAvailability: .waitingForCurrentAttempt) = self { return true }
        return false
    }
}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}
