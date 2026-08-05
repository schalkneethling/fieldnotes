import SwiftData
import SwiftUI
import UIKit

struct StoreStartupFailure: Equatable {
    let domain: String
    let code: Int
    let reference: String

    init(error: any Error, reference: String = String(UUID().uuidString.prefix(8)).uppercased()) {
        let error = error as NSError
        domain = Self.safeDomain(for: error.domain)
        code = error.code
        self.reference = reference
    }

    private static func safeDomain(for domain: String) -> String {
        let knownDomains = [
            NSCocoaErrorDomain,
            NSPOSIXErrorDomain,
            NSMachErrorDomain,
            NSOSStatusErrorDomain
        ]
        return knownDomains.contains(domain) ? domain : "StoreOpenError"
    }

    var diagnostics: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let os = ProcessInfo.processInfo.operatingSystemVersion

        return """
        Reference: \(reference)
        App: \(version) (\(build))
        iOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)
        Store: \(domain) (\(code))
        """
    }
}

@MainActor
final class StoreStartup: ObservableObject {
    enum State {
        case loading
        case ready(ModelContainer)
        case failed(StoreStartupFailure)
    }

    typealias ContainerLoader = @Sendable () throws -> ModelContainer

    @Published private(set) var state: State = .loading

    private let loadContainer: ContainerLoader
    private var isAttemptingLoad = false

    init(loadContainer: @escaping ContainerLoader = { try FieldnotesStoreFactory.makeContainer() }) {
        self.loadContainer = loadContainer
    }

    func start() async {
        guard case .loading = state, !isAttemptingLoad else { return }
        isAttemptingLoad = true
        defer { isAttemptingLoad = false }

        let loadContainer = loadContainer
        let result = await Task.detached(priority: .userInitiated) {
            Result { try loadContainer() }
        }.value

        switch result {
        case .success(let container):
            state = .ready(container)
        case .failure(let error):
            state = .failed(StoreStartupFailure(error: error))
        }
    }

    func retry() async {
        guard case .failed = state else { return }
        state = .loading
        await start()
    }
}

struct StoreStartupView: View {
    @ObservedObject var startup: StoreStartup

    var body: some View {
        Group {
            switch startup.state {
            case .loading:
                ProgressView("Opening your Fieldnotes…")
            case .ready(let container):
                ContentView()
                    .modelContainer(container)
            case .failed(let failure):
                StoreRecoveryView(failure: failure) {
                    Task {
                        await startup.retry()
                    }
                }
            }
        }
        .task {
            await startup.start()
        }
    }
}

struct StoreRecoveryView: View {
    let failure: StoreStartupFailure
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

                Text("Fieldnotes didn’t open a replacement store, and capture is paused to avoid putting new notes somewhere unexpected. Try opening your notes again. If this keeps happening, share the diagnostics below when asking for help.")
                    .foregroundStyle(.secondary)

                Button("Try Again", action: retryAction)
                    .buttonStyle(.borderedProminent)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Diagnostics")
                        .font(.headline)

                    Text(failure.diagnostics)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)

                    Button(didCopyDiagnostics ? "Copied" : "Copy Diagnostics") {
                        UIPasteboard.general.string = failure.diagnostics
                        didCopyDiagnostics = true
                        UIAccessibility.post(notification: .announcement, argument: "Diagnostics copied")
                    }
                    .accessibilityHint(didCopyDiagnostics ? "Technical details were copied." : "Copies technical details only. No Fieldnotes are included.")
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding()
        }
        .onAppear {
            isTitleFocused = true
        }
    }
}
