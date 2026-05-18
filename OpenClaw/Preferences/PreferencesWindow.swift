import SwiftUI

struct PreferencesWindow: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            GeneralTab()
                .environmentObject(appState)
                .tabItem { Label(L("General"), systemImage: "gearshape") }
            ServerTab()
                .environmentObject(appState)
                .tabItem { Label(L("Server"), systemImage: "server.rack") }
            AdvancedTab()
                .environmentObject(appState)
                .tabItem { Label(L("Advanced"), systemImage: "slider.horizontal.3") }
            AboutTab()
                .environmentObject(appState)
                .tabItem { Label(L("About"), systemImage: "info.circle") }
        }
        .padding(20)
        .frame(width: 620, height: 420)
    }
}
