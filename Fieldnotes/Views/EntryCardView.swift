import SwiftUI
import UIKit

struct EntryCardView: View {
    let entry: Fieldnote

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(entry.createdAt.fieldTimestamp, systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if let emoji = entry.emoji {
                    Text(emoji)
                        .font(.title2)
                        .accessibilityLabel("Emotion signal \(emoji)")
                }
            }

            Text(entry.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            if let photoData = entry.photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel("Attached fieldnote photo")
            }
        }
    }
}
