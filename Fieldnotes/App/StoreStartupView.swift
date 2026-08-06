import CoreData
import OSLog
import SwiftData
import SwiftUI
import UIKit

struct StoreErrorCode: Equatable {
    let domain: String
    let code: Int
}

struct StoreStartupFailure {
    let errorCodes: [StoreErrorCode]
    let reference: String
    let presentationID: UUID
    let isTimeout: Bool

    init(error: any Error, reference: String, presentationID: UUID = UUID()) {
        errorCodes = Self.errorCodes(from: error as NSError)
        self.reference = reference
        self.presentationID = presentationID
        isTimeout = false
    }

    static func timeout(reference: String, presentationID: UUID = UUID()) -> StoreStartupFailure {
        StoreStartupFailure(
            errorCodes: [StoreErrorCode(domain: "StoreOpenTimeout", code: 1)],
            reference: reference,
            presentationID: presentationID,
            isTimeout: true
        )
    }

    private init(errorCodes: [StoreErrorCode], reference: String, presentationID: UUID, isTimeout: Bool) {
        self.errorCodes = errorCodes
        self.reference = reference
        self.presentationID = presentationID
        self.isTimeout = isTimeout
    }

    private static func errorCodes(from rootError: NSError) -> [StoreErrorCode] {
        var codes: [StoreErrorCode] = []
        var error: NSError? = rootError
        var visited: Set<ObjectIdentifier> = []

        while let currentError = error, codes.count < 5 {
            let identifier = ObjectIdentifier(currentError)
            guard visited.insert(identifier).inserted else { break }

            codes.append(
                StoreErrorCode(
                    domain: safeDomain(for: currentError.domain),
                    code: currentError.code
                )
            )
            error = currentError.userInfo[NSUnderlyingErrorKey] as? NSError
        }

        return codes
    }

    private static func safeDomain(for domain: String) -> String {
        let knownDomains: Set<String> = [
            "SwiftData.SwiftDataError",
            NSCocoaErrorDomain,
            NSPOSIXErrorDomain,
            NSMachErrorDomain,
            NSOSStatusErrorDomain,
            NSSQLiteErrorDomain
        ]
        return knownDomains.contains(domain) ? domain : "StoreOpenError"
    }

    var diagnostics: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let os = ProcessInfo.processInfo.operatingSystemVersion

        let storeDetails = errorCodes.enumerated().map { index, errorCode in
            let label = index == 0 ? "Store" : "Cause \(index)"
            return "\(label): \(errorCode.domain) (\(errorCode.code))"
        }.joined(separator: "\n")

        return """
        Reference: \(reference)
        App: \(version) (\(build))
        iOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)
        \(storeDetails)
        """
    }
}

private enum StoreStartupReporter {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Fieldnotes",
        category: "StoreStartup"
    )

    static func report(reference: String, safeDetails: String, privateDetails: String) {
        logger.fault(
            "Store open failed [\(reference, privacy: .public)] \(safeDetails, privacy: .public) \(privateDetails, privacy: .private)"
        )
    }
}

@MainActor
final class StoreStartup: ObservableObject {
    enum RetryAvailability: Equatable {
        case available
        case waitingForCurrentAttempt
    }

    enum State {
        case idle
        case opening
        case ready(ModelContainer)
        case failed(StoreStartupFailure, retryAvailability: RetryAvailability)
    }

    typealias ContainerLoader = @Sendable () throws -> ModelContainer
    typealias TimeoutWaiter = @Sendable () async -> Void
    typealias FailureReporter = (_ reference: String, _ safeDetails: String, _ privateDetails: String) -> Void

    @Published private(set) var state: State = .idle

    private let loadContainer: ContainerLoader
    private let waitForTimeout: TimeoutWaiter
    private let reportFailure: FailureReporter
    private let reference: String
    private var activeAttemptID: UUID?
    private var timeoutTask: Task<Void, Never>?

    init(
        reference: String = String(UUID().uuidString.prefix(8)).uppercased(),
        loadContainer: @escaping ContainerLoader = { try FieldnotesStoreFactory.makeContainer() },
        waitForTimeout: @escaping TimeoutWaiter = {
            try? await Task.sleep(for: .seconds(20))
        },
        reportFailure: FailureReporter? = nil
    ) {
        self.reference = reference
        self.loadContainer = loadContainer
        self.waitForTimeout = waitForTimeout
        self.reportFailure = reportFailure ?? StoreStartupReporter.report
    }

    func start() {
        guard case .idle = state else { return }
        beginOpen()
    }

    func retry() {
        guard case .failed(_, retryAvailability: .available) = state else { return }
        beginOpen()
    }

    private func beginOpen() {
        guard activeAttemptID == nil else { return }

        let attemptID = UUID()
        activeAttemptID = attemptID
        state = .opening

        let loadContainer = loadContainer
        let openTask = Task.detached(priority: .userInitiated) {
            Result { try loadContainer() }
        }

        let waitForTimeout = waitForTimeout
        timeoutTask = Task { [weak self] in
            await waitForTimeout()
            guard !Task.isCancelled else { return }
            self?.handleTimeout(for: attemptID)
        }

        Task { [weak self] in
            let result = await openTask.value
            self?.handleCompletion(result, for: attemptID)
        }
    }

    private func handleTimeout(for attemptID: UUID) {
        guard activeAttemptID == attemptID else { return }

        let failure = StoreStartupFailure.timeout(reference: reference)
        reportFailure(reference, failure.diagnostics, "ModelContainer initialization exceeded the startup timeout.")
        state = .failed(failure, retryAvailability: .waitingForCurrentAttempt)
    }

    private func handleCompletion(_ result: Result<ModelContainer, any Error>, for attemptID: UUID) {
        guard activeAttemptID == attemptID else { return }

        activeAttemptID = nil
        timeoutTask?.cancel()
        timeoutTask = nil

        switch result {
        case .success(let container):
            state = .ready(container)
        case .failure(let error):
            let failure = StoreStartupFailure(error: error, reference: reference)
            reportFailure(reference, failure.diagnostics, String(reflecting: error))
            state = .failed(failure, retryAvailability: .available)
        }
    }
}

struct StoreStartupView: View {
    @ObservedObject var startup: StoreStartup

    var body: some View {
        Group {
            switch startup.state {
            case .idle, .opening:
                ProgressView("Opening your Fieldnotes…")
            case .ready(let container):
                ContentView()
                    .modelContainer(container)
            case .failed(let failure, let retryAvailability):
                StoreRecoveryView(failure: failure, retryAvailability: retryAvailability) {
                    startup.retry()
                }
                .id(failure.presentationID)
            }
        }
        .task {
            startup.start()
        }
    }
}

struct StoreRecoveryView: View {
    let failure: StoreStartupFailure
    let retryAvailability: StoreStartup.RetryAvailability
    let retryAction: () -> Void

    @AccessibilityFocusState private var isTitleFocused: Bool
    @State private var didCopyDiagnostics = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text("Fieldnotes couldn’t open your notes")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)

                Text(recoveryMessage)
                    .foregroundStyle(.secondary)

                Button(retryAvailability == .available ? "Try Again" : "Still Trying…", action: retryAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(retryAvailability != .available)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Diagnostics")
                        .font(.headline)

                    Text(failure.diagnostics)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)

                    Button(didCopyDiagnostics ? "Copied" : "Copy Diagnostics") {
                        UIPasteboard.general.string = failure.diagnostics
                        didCopyDiagnostics = true
                    }
                    .accessibilityLabel("Copy Diagnostics")
                    .accessibilityValue(didCopyDiagnostics ? "Copied" : "Not copied")
                    .accessibilityHint(didCopyDiagnostics ? "Technical details were copied." : "Copies technical details only. No Fieldnotes are included.")
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding()
        }
        .onAppear {
            isTitleFocused = true
        }
        .task(id: didCopyDiagnostics) {
            guard didCopyDiagnostics else { return }
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let announcement = NSAttributedString(
                string: "Diagnostics copied",
                attributes: [.accessibilitySpeechAnnouncementPriority: UIAccessibilityPriority.low]
            )
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }

    private var recoveryMessage: String {
        if failure.isTimeout {
            return "Opening your Fieldnotes is taking longer than expected. Capture remains paused, and Fieldnotes is still waiting for the current attempt so it doesn’t open the same store twice. If it does not recover, close and reopen the app."
        }

        return "Fieldnotes didn’t open a replacement store, and capture is paused to avoid putting new notes somewhere unexpected. Try opening your notes again. If this keeps happening, share the diagnostics below when asking for help."
    }
}
