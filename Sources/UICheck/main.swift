import AppKit
import SwiftUI
@testable import GatewayBarKit

// UI tests for Enexis AI Gateway: real SwiftUI views, hosted in a window, driven through the
// accessibility tree (what VoiceOver and XCUITest see). Run: `swift run UICheck`. Exit code 1 on any failure.

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
do {  // SwiftUI only builds its accessibility tree when assistive tech is active
    for attr in ["AXEnhancedUserInterface", "AXManualAccessibility"] {
        app.perform(Selector(("accessibilitySetValue:forAttribute:")), with: true as NSNumber, with: attr as NSString)
    }
}
let cfg = URLSessionConfiguration.ephemeral
cfg.protocolClasses = [StubProtocol.self]
GatewayClient.session = URLSession(configuration: cfg)

@MainActor func settle(_ ms: UInt64 = 250) async { try? await Task.sleep(nanoseconds: ms * 1_000_000) }

@MainActor func scenarios() async {
    print("UI checks")
    if CommandLine.arguments.contains("--dump") {
        let s = freshStore(Gateway()); await s.refresh(); let ui = Screen(MenuView(s: s)); await settle()
        let ns = ui.nodes(); print("nodes:", ns.count)
        for n in ns.prefix(60) { print(n.role, "|", n.label, "|", n.value, "|", n.id) }
        return
    }

    await T.run("healthy gateway shows spend, budget, models") {
        let s = freshStore(Gateway()); await s.refresh()
        let ui = Screen(MenuView(s: s))
        T.eq(s.health, .ok, "health")
        T.has(ui, "Enexis AI Gateway"); T.has(ui, "Alles operationeel")
        T.eq(ui.node(id: "heroAmount")?.text ?? "", "$4.20", "hero amount")
        T.has(ui, "VERBRUIK · MAANDELIJKS"); T.has(ui, "van $10.00 maandelijks"); T.has(ui, "42%")
        T.has(ui, "gpt-4o, beschikbaar"); T.has(ui, "claude-sonnet, beschikbaar")
        T.has(ui, "2 van 2 beschikbaar"); T.hasNot(ui, "UIT")
        T.has(ui, "Bijgewerkt")
    }

    await T.run("weekly $120 budget comes from the gateway") {
        var g = Gateway(); g.keyInfo = ["spend": 30, "max_budget": 120, "budget_duration": "7d"]
        let s = freshStore(g); await s.refresh(); let ui = Screen(MenuView(s: s))
        T.has(ui, "VERBRUIK · WEKELIJKS"); T.has(ui, "van $120.00 wekelijks"); T.has(ui, "25%")
        T.eq(s.title, "$30.00", "bar title")
    }

    await T.run("team budget is used when the key has none") {
        var g = Gateway(); g.keyInfo = ["spend": 1, "key_alias": "k"]
        g.teamInfo = ["team_alias": "Data", "spend": 60, "max_budget": 120, "budget_duration": "7d"]
        let s = freshStore(g); await s.refresh(); let ui = Screen(MenuView(s: s))
        T.has(ui, "50%"); T.has(ui, "van $120.00 wekelijks"); T.has(ui, "Data")
        T.eq(ui.node(id: "heroAmount")?.text ?? "", "$60.00", "team spend")
    }

    await T.run("over budget shows >100% and caps the bar") {
        var g = Gateway(); g.keyInfo = ["spend": 12, "max_budget": 10, "budget_duration": "1d"]
        let s = freshStore(g); await s.refresh(); let ui = Screen(MenuView(s: s))
        T.has(ui, "120%"); T.has(ui, "dagelijks"); T.eq(s.budget?.fraction ?? 0, 1.2, "fraction")
    }

    await T.run("unavailable model: degraded state, UIT badge, count") {
        var g = Gateway(); g.healthy = ["gpt-4o"]
        let s = freshStore(g); await s.refresh(); let ui = Screen(MenuView(s: s))
        T.eq(s.health, .degraded, "health"); T.check(s.badge != nil, "badge visible")
        T.has(ui, "1 model onbeschikbaar"); T.has(ui, "claude-sonnet, niet beschikbaar"); T.has(ui, "1 van 2 beschikbaar")
        let ids = ui.nodes().filter { $0.id.hasPrefix("model-") }.map(\.id)
        T.eq(ids.first ?? "", "model-claude-sonnet", "unavailable model listed first")
    }

    await T.run("several unavailable models are counted") {
        var g = Gateway(); g.healthy = []
        let s = freshStore(g); await s.refresh(); let ui = Screen(MenuView(s: s))
        T.has(ui, "2 modellen onbeschikbaar"); T.has(ui, "0 van 2 beschikbaar")
    }

    await T.run("gateway down: offline state with way to settings") {
        var g = Gateway(); g.alive = false
        let s = freshStore(g); await s.refresh(); let ui = Screen(MenuView(s: s))
        T.eq(s.health, .down, "health"); T.eq(s.title, "offline", "bar title")
        T.has(ui, "Gateway niet bereikbaar"); T.eq(ui.node(id: "heroMessage")?.text ?? "", "Niet bereikbaar", "hero")
        T.check(ui.node(id: "openSettings") != nil, "open settings button")
    }

    await T.run("rejected key: auth error state") {
        var g = Gateway(); g.status = 401
        let s = freshStore(g); await s.refresh(); let ui = Screen(MenuView(s: s))
        T.eq(s.health, .authError, "health"); T.eq(s.title, "key?", "bar title")
        T.has(ui, "Key geweigerd")
    }

    await T.run("not configured: invalid URL and empty state") {
        let s = freshStore(Gateway()); s.baseURLString = "geen url"; await s.refresh()
        T.eq(s.health, .unknown, "health"); T.check(s.badge == nil, "no badge when unknown")
        let ui = Screen(MenuView(s: s))
        T.has(ui, "Ongeldige gateway-URL"); T.eq(ui.node(id: "heroMessage")?.text ?? "", "Nog niet verbonden", "hero")
        T.has(ui, "Geen modellen zichtbaar"); T.has(ui, "Nog niet bijgewerkt")
    }

    await T.run("normal key without admin rights: month shows a dash") {
        var g = Gateway(); g.month = nil
        let s = freshStore(g); await s.refresh(); let ui = Screen(MenuView(s: s))
        T.eq(ui.node(id: "tile-Maand")?.text ?? "", "Maand, –", "month tile"); T.eq(s.health, .ok, "still healthy")
    }

    await T.run("spend tiles and per-model spend") {
        let s = freshStore(Gateway()); await s.refresh(); let ui = Screen(MenuView(s: s))
        T.eq(ui.node(id: "tile-Vandaag")?.text ?? "", "Vandaag, $1.50", "today"); T.eq(ui.node(id: "tile-Maand")?.text ?? "", "Maand, $99.50", "month")
        T.has(ui, "$1.50")
    }

    await T.run("menu bar title for every style") {
        let s = freshStore(Gateway()); await s.refresh()
        for (style, want) in [("amount", "$4.20"), ("percent", "42%"), ("both", "$4 · 42%"), ("icon", "")] {
            s.barStyle = style; T.eq(s.title, want, "style \(style)")
        }
        var g = Gateway(); g.keyInfo = ["spend": 150]
        let s2 = freshStore(g); await s2.refresh()
        T.eq(s2.title, "$150", "large amounts drop cents"); s2.barStyle = "percent"; T.eq(s2.title, "$150", "percent falls back to amount")
        let s3 = freshStore(Gateway()); T.eq(s3.title, "–", "no data yet")
    }

    await T.run("model list collapses and expands") {
        var g = Gateway(); g.models = (1...8).map { "model-\($0)" }
        let s = freshStore(g); await s.refresh(); let ui = Screen(MenuView(s: s))
        @MainActor func count() -> Int { ui.nodes().filter { $0.id.hasPrefix("model-model") }.count }
        T.eq(count(), 5, "collapsed rows"); T.has(ui, "3 meer")
        T.check(ui.press(id: "toggleModels"), "press toggle"); await settle()
        let ui2 = Screen(MenuView(s: s))
        T.eq(ui2.nodes().filter { $0.id.hasPrefix("model-model") }.count, 8, "expanded rows"); T.has(ui2, "Minder")
        s.showAll = false
    }

    await T.run("refresh button fetches again") {
        let s = freshStore(Gateway()); await s.refresh()
        let ui = Screen(MenuView(s: s)); StubProtocol.requests = []
        T.check(ui.press(id: "refresh"), "press refresh"); await settle(600)
        T.check(StubProtocol.requests.contains { $0.hasPrefix("/key/info") }, "key/info requested; got \(StubProtocol.requests)")
    }

    await T.run("requests use the key only where needed") {
        let s = freshStore(Gateway(), key: "sk-abc"); await s.refresh()
        T.eq(StubProtocol.auth["/key/info"] ?? "", "Bearer sk-abc", "key/info auth")
        T.eq(StubProtocol.auth["/health/liveliness"] ?? "", "none", "liveness is unauthenticated")
    }

    await T.run("settings button opens the settings window") {
        let s = freshStore(Gateway()); await s.refresh(); let ui = Screen(MenuView(s: s))
        SettingsWindow.window?.close(); SettingsWindow.window = nil
        T.check(ui.press(id: "settings"), "press settings"); await settle()
        T.check(SettingsWindow.window?.isVisible == true, "settings window visible")
        T.eq(SettingsWindow.window?.title ?? "", "Enexis AI Gateway", "window title")
        SettingsWindow.window?.close()
    }

    await T.run("hero 'Open instellingen' opens the settings window") {
        var g = Gateway(); g.alive = false
        let s = freshStore(g); await s.refresh(); let ui = Screen(MenuView(s: s))
        SettingsWindow.window?.close(); SettingsWindow.window = nil
        T.check(ui.press(id: "openSettings"), "press"); await settle()
        T.check(SettingsWindow.window?.isVisible == true, "settings window visible"); SettingsWindow.window?.close()
    }

    await T.run("settings form has all controls") {
        let s = freshStore(Gateway()); let ui = Screen(SettingsView(s: s))
        for id in ["urlField", "keyField", "save"] { T.check(ui.node(id: id) != nil, "missing \(id)") }
        for t in ["Verbinding", "Gedrag", "Verversen", "Waarschuwing bij", "Menubalk toont", "Meldingen", "Start bij inloggen", "Opslaan"] { T.has(ui, t) }
    }

    await T.run("menu bar icon renders with and without status") {
        for c in [nil, Color.green, Color.red] as [Color?] {
            let img = menuBarMark(status: c); T.check(img.size.width > 10 && img.size.height > 10, "size \(img.size)")
            T.check(!img.isTemplate, "colour image, not template")
        }
    }

    await T.run("every footer and header control is a real button") {
        let s = freshStore(Gateway()); await s.refresh(); let ui = Screen(MenuView(s: s))
        for id in ["refresh", "settings", "quit"] {
            let n = ui.node(id: id); T.check(n != nil, "\(id) missing")
            T.check(((n?.obj.value(forKey: "accessibilityFrame") as? NSValue)?.rectValue.size.width ?? 0) >= 24, "\(id) click target too small")
        }
    }
}

Task { @MainActor in
    await scenarios()
    print("\n\(T.passed) checks passed, \(T.failures.count) failed")
    T.failures.forEach { print("FAIL " + $0) }
    exit(T.failures.isEmpty ? 0 : 1)
}
app.run()
