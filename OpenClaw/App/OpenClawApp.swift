import SwiftUI

@main
struct OpenClawApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            StatusIndicator(status: appState.serverStatus)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesWindow()
                .environmentObject(appState)
        }
    }
}

