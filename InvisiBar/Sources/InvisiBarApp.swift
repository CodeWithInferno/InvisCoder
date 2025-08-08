import SwiftUI

@main
struct InvisiBarApp: App {
    // The AppDelegate is now the single source of truth.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            // This is required for the app lifecycle but remains empty and invisible.
            EmptyView()
        }
    }
}