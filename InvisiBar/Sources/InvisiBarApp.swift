import SwiftUI

@main
struct InvisiBarApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
    
    init() {
        appDelegate.appState = appState
    }
}
