import SwiftUI
import GatewayBarKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Opening the app again (Finder, Spotlight) shows the dashboard in a normal window,
    /// so it stays reachable when the menu bar is too crowded and macOS hides the item.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in DashboardWindow.show(Store.shared) }
        return true
    }
}

@main
struct GatewayBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = Store.shared
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

    }
}
