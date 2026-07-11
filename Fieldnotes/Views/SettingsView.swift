import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

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
