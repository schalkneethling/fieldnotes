import SwiftUI

struct ReflectionCuePanel: View {
    let entries: [Fieldnote]
    let range: EntryRange

    private var cues: [String] {
        ReflectionCuePanel.makeCues(for: entries, range: range)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(cues, id: \.self) { cue in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "seal")
                        .foregroundStyle(.tint)
                        .padding(.top, 2)

                    Text(cue)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private static func makeCues(for entries: [Fieldnote], range: EntryRange) -> [String] {
        guard !entries.isEmpty else {
            return ["No artifacts logged \(range.cuePeriod) yet."]
        }

        var cues = ["\(entries.count) \(Self.noteNoun(for: entries.count)) surfaced \(range.cuePeriod)."]

        if let dominantEmoji = dominantEmoji(in: entries) {
            cues.append("\(dominantEmoji) is your most frequent feeling.")
        }

        if let timeWindow = dominantTimeWindow(in: entries) {
            cues.append("Most notes cluster in the \(timeWindow).")
        }

        let photoCount = entries.filter { $0.photoData != nil }.count
        if photoCount > 0 {
            cues.append("\(photoCount) \(Self.noteNoun(for: photoCount)) \(photoCount == 1 ? "includes" : "include") a visual artifact.")
        }

        if let recurringWord = recurringWord(in: entries) {
            cues.append("The word \"\(recurringWord)\" repeats across your notes.")
        }

        return Array(cues.prefix(4))
    }

    private static func noteNoun(for count: Int) -> String {
        count == 1 ? "note" : "notes"
    }

    private static func dominantEmoji(in entries: [Fieldnote]) -> String? {
        let counts = Dictionary(grouping: entries.compactMap(\.emoji), by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key
    }

    private static func dominantTimeWindow(in entries: [Fieldnote]) -> String? {
        let calendar = Calendar.current
        let windows = entries.map { entry -> String in
            let hour = calendar.component(.hour, from: entry.createdAt)
            switch hour {
            case 5..<12: return "morning"
            case 12..<17: return "afternoon"
            case 17..<22: return "evening"
            default: return "night"
            }
        }

        let counts = Dictionary(grouping: windows, by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key
    }

    private static func recurringWord(in entries: [Fieldnote]) -> String? {
        let stopWords: Set<String> = ["about", "after", "again", "also", "and", "because", "but", "for", "from", "had", "have", "into", "just", "like", "moment", "note", "that", "the", "this", "was", "with", "you"]
        let words = entries
            .flatMap { $0.text.lowercased().split { !$0.isLetter } }
            .map(String.init)
            .filter { $0.count > 3 && !stopWords.contains($0) }

        let counts = Dictionary(grouping: words, by: { $0 }).mapValues(\.count)
        return counts
            .filter { $0.value > 1 }
            .max { $0.value < $1.value }?
            .key
    }
}

private extension EntryRange {
    var cuePeriod: String {
        switch self {
        case .day: "today"
        case .week: "in the last 7 days"
        case .month: "in the last month"
        }
    }
}
