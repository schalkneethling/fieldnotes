import SwiftData
import SwiftUI

enum EntryRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        }
    }

    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .day:
            return calendar.isDate(date, inSameDayAs: now)
        case .week:
            guard let startDate = calendar.date(byAdding: .day, value: -7, to: now) else {
                return false
            }

            return startDate...now ~= date
        case .month:
            guard let startDate = calendar.date(byAdding: .month, value: -1, to: now) else {
                return false
            }

            return startDate...now ~= date
        }
    }
}

struct ContentView: View {
    @Query(sort: \Fieldnote.createdAt, order: .reverse) private var entries: [Fieldnote]

    @State private var selectedRange = EntryRange.day
    @State private var isShowingEditor = false
    @State private var isShowingReview = false
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .padding(.vertical, 4)

                    Button {
                        isShowingEditor = true
                    } label: {
                        Label("Capture fieldnote", systemImage: "camera.viewfinder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.vertical, 4)
                }

                if let latestEntry = entries.first {
                    Section("Latest") {
                        LatestEntrySummary(entry: latestEntry) {
                            isShowingReview = true
                        }
                    }
                }
            }
            .navigationTitle("Fieldnotes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingReview = true
                    } label: {
                        Label("Review", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .sheet(isPresented: $isShowingEditor) {
                EntryEditorView()
            }
            .sheet(isPresented: $isShowingReview) {
                ReviewView(entries: entries, selectedRange: $selectedRange)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Right now")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("Capture the moment before it changes.")
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            Text("A short note, and a photo if it helps.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ReviewView: View {
    let entries: [Fieldnote]
    @Binding var selectedRange: EntryRange
    @Environment(\.dismiss) private var dismiss

    private var visibleEntries: [Fieldnote] {
        entries.filter { selectedRange.contains($0.createdAt) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    rangePicker
                }

                Section("Reflection Cues") {
                    ReflectionCuePanel(entries: visibleEntries, range: selectedRange)
                }

                Section("Field Log") {
                    FieldnoteTimelineView(entries: visibleEntries)
                }
            }
            .navigationTitle("Review")
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

    private var rangePicker: some View {
        Picker("Time range", selection: $selectedRange) {
            ForEach(EntryRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct FieldnoteTimelineView: View {
    let entries: [Fieldnote]

    var body: some View {
        if entries.isEmpty {
            EmptyFieldnoteRangeView()
        } else {
            ForEach(entries) { entry in
                EntryCardView(entry: entry)
            }
        }
    }
}

struct EmptyFieldnoteRangeView: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("No notes in this range")
                    .font(.subheadline.weight(.semibold))

                Text("Add a small observation when the next moment catches your attention.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
        } icon: {
            Image(systemName: "map")
        }
    }
}

struct LatestEntrySummary: View {
    let entry: Fieldnote
    let reviewAction: () -> Void

    var body: some View {
        Button(action: reviewAction) {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Last saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(entry.createdAt.fieldTimestamp)
                        .font(.subheadline)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Review latest fieldnote")
    }
}
