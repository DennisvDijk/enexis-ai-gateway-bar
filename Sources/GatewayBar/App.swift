import SwiftUI

@main
struct GatewayBarApp: App {
    @StateObject private var store = Store()
    init() { NSApplication.shared.setActivationPolicy(.accessory) }

    var body: some Scene {
        MenuBarExtra {
            MenuView(s: store)
        } label: {
            Image(nsImage: menuBarMark(status: store.badge))
            Text(store.title).monospacedDigit()
                .task { store.start() }
        }
        .menuBarExtraStyle(.window)

        Settings { SettingsView(s: store) }
    }
}
