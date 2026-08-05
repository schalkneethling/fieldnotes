import Foundation
import SwiftData

@MainActor
enum FieldnotePersistence {
    @discardableResult
    static func save(
        text: String,
        emoji: String?,
        photoData: Data?,
        createdAt: Date = .now,
        in context: ModelContext
    ) throws -> Fieldnote {
        let fieldnote = Fieldnote(text: text, emoji: emoji, photoData: photoData, createdAt: createdAt)
        context.insert(fieldnote)

        do {
            if context.hasChanges {
                try context.save()
            }
            return fieldnote
        } catch {
            context.rollback()
            throw error
        }
    }
}
