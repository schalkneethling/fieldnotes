import SwiftUI

@main
struct FieldnotesApp: App {
    @StateObject private var storeStartup = StoreStartup()

    var body: some Scene {
        WindowGroup {
            StoreStartupView(startup: storeStartup)
        }
    }
}
