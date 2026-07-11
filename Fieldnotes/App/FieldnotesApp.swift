import SwiftData
import SwiftUI

@main
struct FieldnotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Fieldnote.self)
    }
}
