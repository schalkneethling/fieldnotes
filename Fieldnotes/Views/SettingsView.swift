import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var exportDocument: FieldnotesArchiveDocument?
    @State private var isShowingExporter = false
    @State private var isShowingImporter = false
    @State private var isPreparingData = false
    @State private var pendingRestore: PendingRestore?
    @State private var dataMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("AI Field Assistant", systemImage: "wand.and.stars")
                        .font(.headline)

                    Text("Connect an AI provider later to ask for patterns across your notes. This scaffold keeps every note local and makes no network calls.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Principles") {
                    SettingsRow(icon: "lock", title: "Local first", detail: "SwiftData stores entries on this device.")
                    SettingsRow(icon: "key", title: "Provider neutral", detail: "No API key or account is required yet.")
                    SettingsRow(icon: "person.crop.circle.badge.questionmark", title: "User controlled", detail: "Future AI summaries should run only after you ask.")
                }

                Section("Your data") {
                    Button(action: prepareExport) {
                        Label("Export all Fieldnotes", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        isShowingImporter = true
                    } label: {
                        Label("Restore from archive", systemImage: "square.and.arrow.down")
                    }

                    if isPreparingData {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Preparing your Fieldnotes…")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Archives are manual copies of every Fieldnote and attached photo. They are not encrypted by Fieldnotes, so save them somewhere private.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .disabled(isPreparingData)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fileExporter(
            isPresented: $isShowingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "Fieldnotes Archive"
        ) { result in
            exportDocument = nil
            if case .failure(let error) = result {
                dataMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                prepareRestore(from: url)
            case .failure(let error):
                dataMessage = error.localizedDescription
            }
        }
        .alert(
            "Restore this archive?",
            isPresented: Binding(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            )
        ) {
            Button("Restore") {
                restorePendingArchive()
            }
            Button("Cancel", role: .cancel) {
                pendingRestore = nil
            }
        } message: {
            if let pendingRestore {
                Text(pendingRestore.message)
            }
        }
        .alert(
            "Your data",
            isPresented: Binding(
                get: { dataMessage != nil },
                set: { if !$0 { dataMessage = nil } }
            )
        ) {
            Button("OK") {
                dataMessage = nil
            }
        } message: {
            if let dataMessage {
                Text(dataMessage)
            }
        }
    }

    private func prepareExport() {
        isPreparingData = true

        Task { @MainActor in
            do {
                let archiveStore = FieldnotesArchiveStore(modelContainer: modelContext.container)
                let records = try await archiveStore.exportRecords()
                let exportedAt = Date.now
                let data = try await Task.detached(priority: .userInitiated) {
                    let archive = try FieldnotesArchiveCodec.makeArchive(
                        from: records,
                        exportedAt: exportedAt
                    )
                    return try FieldnotesArchiveCodec.encode(archive)
                }.value

                exportDocument = FieldnotesArchiveDocument(data: data)
                isShowingExporter = true
            } catch {
                dataMessage = error.localizedDescription
            }
            isPreparingData = false
        }
    }

    private func prepareRestore(from url: URL) {
        isPreparingData = true

        Task { @MainActor in
            do {
                let archive = try await Task.detached(priority: .userInitiated) {
                    let hasSecurityAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if hasSecurityAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    return try FieldnotesArchiveCodec.read(from: url)
                }.value
                let archiveStore = FieldnotesArchiveStore(modelContainer: modelContext.container)
                let preview = try await archiveStore.previewRestore(archive)
                pendingRestore = PendingRestore(archive: archive, preview: preview)
            } catch {
                dataMessage = error.localizedDescription
            }
            isPreparingData = false
        }
    }

    private func restorePendingArchive() {
        guard let pendingRestore else { return }
        self.pendingRestore = nil
        isPreparingData = true

        Task { @MainActor in
            do {
                await Task.yield()
                let archiveStore = FieldnotesArchiveStore(modelContainer: modelContext.container)
                let result = try await archiveStore.restore(pendingRestore.archive)
                dataMessage = restoreMessage(for: result)
            } catch {
                dataMessage = error.localizedDescription
            }
            isPreparingData = false
        }
    }

    private func restoreMessage(for result: FieldnotesRestoreResult) -> String {
        if result.addedFieldnoteCount == 0 {
            return "Everything in this archive is already here. Nothing changed."
        }

        let noun = result.addedFieldnoteCount == 1 ? "Fieldnote" : "Fieldnotes"
        return "Restored \(result.addedFieldnoteCount) \(noun). \(result.existingFieldnoteCount) already present."
    }
}

private struct PendingRestore {
    let archive: FieldnotesArchive
    let preview: FieldnotesRestorePreview

    var message: String {
        let newNoun = preview.newFieldnoteCount == 1 ? "Fieldnote" : "Fieldnotes"
        return "This archive contains \(preview.fieldnoteCount) Fieldnotes. Restore \(preview.newFieldnoteCount) new \(newNoun.lowercased()) and keep \(preview.existingFieldnoteCount) already on this device? Nothing will be overwritten or deleted."
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
