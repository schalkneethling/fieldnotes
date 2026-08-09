import Foundation
import SwiftData
import SwiftUI

@main
struct FieldnotesApp: App {
    @StateObject private var storeStartup: StoreStartup
    private let saveAction: FieldnoteSaveAction

    init() {
        let configuration = FieldnotesAppConfiguration.current()
        _storeStartup = StateObject(wrappedValue: configuration.storeStartup)
        saveAction = configuration.saveAction
    }

    var body: some Scene {
        WindowGroup {
            StoreStartupView(startup: storeStartup)
                .environment(\.fieldnoteSaveAction, saveAction)
        }
    }
}

@MainActor
private struct FieldnotesAppConfiguration {
    let storeStartup: StoreStartup
    let saveAction: FieldnoteSaveAction

    static func current() -> FieldnotesAppConfiguration {
#if DEBUG
        if let testConfiguration = uiTestConfiguration() {
            return testConfiguration
        }
#endif
        return FieldnotesAppConfiguration(
            storeStartup: StoreStartup(),
            saveAction: .live
        )
    }

#if DEBUG
    private static func uiTestConfiguration() -> FieldnotesAppConfiguration? {
        let environment = ProcessInfo.processInfo.environment
        guard let identifierValue = environment["FIELDNOTES_UI_TEST_STORE_IDENTIFIER"],
              let identifier = UUID(uuidString: identifierValue) else {
            return nil
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FieldnotesUITests", isDirectory: true)
        let storeURL = directory
            .appendingPathComponent(identifier.uuidString)
            .appendingPathExtension("store")
        let shouldFailStoreOpen = environment["FIELDNOTES_UI_TEST_FAIL_FIRST_STORE_OPEN"] == "1"
        let storeFailure = OneShotFailure(isPending: shouldFailStoreOpen)
        let startup = StoreStartup(loadContainer: {
            if storeFailure.consume() {
                throw CocoaError(.fileReadUnknown)
            }
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return try FieldnotesStoreFactory.makeContainer(
                configuration: ModelConfiguration(
                    schema: FieldnotesStoreFactory.schema,
                    url: storeURL
                )
            )
        })

        let saveFailure = OneShotFailure(
            isPending: environment["FIELDNOTES_UI_TEST_FAIL_FIRST_SAVE"] == "1"
        )
        let saveAction = FieldnoteSaveAction { container, text, emoji, photoData in
            if saveFailure.consume() {
                throw CocoaError(.fileWriteUnknown)
            }
            return try await FieldnoteSaveAction.live(
                container: container,
                text: text,
                emoji: emoji,
                photoData: photoData
            )
        }

        return FieldnotesAppConfiguration(
            storeStartup: startup,
            saveAction: saveAction
        )
    }
#endif
}

#if DEBUG
private final class OneShotFailure: @unchecked Sendable {
    private let lock = NSLock()
    private var isPending: Bool

    init(isPending: Bool) {
        self.isPending = isPending
    }

    func consume() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard isPending else { return false }
        isPending = false
        return true
    }
}
#endif
