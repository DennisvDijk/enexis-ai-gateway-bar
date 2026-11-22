import SwiftUI
import ServiceManagement

// MARK: - Popover

struct MenuView: View {
    @ObservedObject var s: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            heroCard
            tiles
            modelsSection
            footer
        }
        .padding(16)
        .frame(width: 340)
    }

    var header: some View {
        HStack(spacing: 10) {
            EnexisMark().frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Enexis AI Gateway").font(.system(size: 14, weight: .bold))
                HStack(spacing: 5) {
                    Circle().fill(s.tint).frame(width: 6, height: 6)
                    Text(s.statusLine).font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if s.refreshing { ProgressView().controlSize(.mini) }
            else { IconButton(name: "arrow.clockwise", label: "Vernieuw") { Task { await s.refresh() } } }
        }
    }

    var connected: Bool { s.budget != nil || s.spendToday != nil }

    // Brand card: gradient, big white number, budget bar, sparkline
    var heroCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Brand.pink, Color(red: 0.45, green: 0, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().fill(Brand.green.opacity(0.55)).frame(width: 140, height: 140).blur(radius: 50).offset(x: 190, y: -50)
            if s.health == .authError {
                heroMessage("Key geweigerd", "Controleer je key in instellingen.", settings: true)
            } else if s.health == .down {
                heroMessage("Niet bereikbaar", "Controleer de URL of je verbinding.", settings: true)
            } else if !connected {
                heroMessage("Nog niet verbonden", "Vul je gateway-URL en key in.", settings: true)
            } else {
                heroNumbers
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(height: 138)
    }

    func heroMessage(_ title: String, _ sub: String, settings: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            Text(title).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(sub).font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
            if settings {
                Button(action: { SettingsWindow.show(s) }) { Text("Open instellingen").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7).background(Capsule().fill(.white.opacity(0.22))).contentShape(Capsule()) }
                    .buttonStyle(.plain).padding(.top, 6)
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
    }

    var heroNumbers: some View {
        let amount = s.budget?.spend ?? s.spendToday ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            Text(s.budget?.period.map { "VERBRUIK · " + $0.uppercased() } ?? (s.budget != nil ? "VERBRUIK" : "VANDAAG")).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.white.opacity(0.7))
            Text(money(amount)).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
            Text(s.budget.map(sub) ?? "").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.8))
            Spacer(minLength: 6)
            if let f = s.budget?.fraction {
                HStack(spacing: 8) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.25))
                            Capsule().fill(f >= 1 ? Color.red : f >= s.alertAt ? Color.orange : Brand.green).frame(width: max(6, g.size.width * min(f, 1)))
                        }
                    }.frame(height: 6)
                    Text("\(Int(f * 100))%").font(.system(size: 11, weight: .semibold)).monospacedDigit().foregroundStyle(.white)
                }
            } else if s.history.count > 2 {
                Sparkline(values: s.history, color: .white).frame(height: 18)
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
    }

    func sub(_ b: BudgetInfo) -> String {
        var parts: [String] = []
        if let m = b.maxBudget { parts.append("van \(money(m))" + (b.period.map { " \($0)" } ?? "")) }
        if let r = b.resetAt { parts.append("reset " + r.formatted(.relative(presentation: .named))) }
        return parts.joined(separator: " · ")
    }

    var tiles: some View {
        HStack(spacing: 8) {
            Tile(label: "Vandaag", value: s.spendToday.map(money) ?? "–")
            Tile(label: "Maand", value: s.spendMonth.map(money) ?? "–")
            if let t = s.team { Tile(label: t.name, value: money(t.spend)) }
            else if let r = s.budget?.rpm { Tile(label: "RPM", value: "\(Int(r))") }
        }
    }

    var modelsSection: some View {
        let down = s.models.filter { !$0.available }
        let up = s.models.filter { $0.available }.sorted { ($0.spendToday, $1.id) > ($1.spendToday, $0.id) }
        let all = down + up
        let list = s.showAll ? all : Array(all.prefix(5))
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("MODELLEN").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.tertiary)
                Spacer()
                if !s.models.isEmpty {
                    Text("\(up.count) van \(s.models.count) beschikbaar").font(.system(size: 10.5, weight: .medium)).foregroundStyle(down.isEmpty ? Color.secondary : Color.orange)
                }
            }
            if s.models.isEmpty {
                Text("Geen modellen zichtbaar").font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(list) { m in
                        HStack(spacing: 8) {
                            Circle().fill(m.available ? Brand.green : Color.red).frame(width: 7, height: 7)
                            Text(m.id).font(.system(size: 12.5, weight: .medium)).lineLimit(1).truncationMode(.middle)
                                .foregroundStyle(m.available ? .primary : .secondary)
                            Spacer()
                            if !m.available {
                                Text("UIT").font(.system(size: 9.5, weight: .bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Color.red))
                            } else if m.spendToday > 0 {
                                Text(money(m.spendToday)).font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 7).padding(.horizontal, 12)
                        if m.id != list.last?.id { Divider().opacity(0.5).padding(.leading, 12) }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
            }
            if all.count > 5 {
                Button(s.showAll ? "Minder" : "\(all.count - 5) meer") { s.showAll.toggle() }
                    .buttonStyle(.plain).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Brand.pink).contentShape(Rectangle())
            }
        }
    }

    var footer: some View {
        HStack(spacing: 4) {
            Text(s.lastUpdate.map { "Bijgewerkt " + $0.formatted(date: .omitted, time: .shortened) } ?? "Nog niet bijgewerkt")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
            Spacer()
            IconButton(name: "gearshape", label: "Instellingen") { SettingsWindow.show(s) }
            IconButton(name: "power", label: "Afsluiten") { NSApp.terminate(nil) }
        }
    }
}

func money(_ v: Double) -> String { v >= 1000 ? String(format: "$%.0f", v) : String(format: "$%.2f", v) }

// MARK: - Components

struct IconButton: View {
    let name: String
    var label: String = ""
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 13)).foregroundStyle(.secondary)
                .frame(width: 30, height: 30).contentShape(Rectangle())
        }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
}

@MainActor enum DashboardWindow {
    private static var window: NSWindow?
    static func show(_ s: Store) {
        if window == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Enexis AI Gateway"
            w.contentView = NSHostingView(rootView: MenuView(s: s))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Own settings window: SettingsLink / showSettingsWindow are unreliable from a menu bar popover of an accessory app.
@MainActor enum SettingsWindow {
    private static var window: NSWindow?
    static func show(_ s: Store) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Enexis AI Gateway"
            w.contentView = NSHostingView(rootView: SettingsView(s: s))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct Tile: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}

struct Sparkline: View {
    let values: [Double]
    var color: Color = Brand.pink
    var body: some View {
        GeometryReader { g in
            let lo = values.min() ?? 0
            let hi = max(values.max() ?? 1, lo + 0.0001)
            let pts: [CGPoint] = values.enumerated().map { i, v in
                CGPoint(x: g.size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1)),
                        y: g.size.height * (1 - CGFloat((v - lo) / (hi - lo))))
            }
            ZStack {
                Path { p in
                    guard let f = pts.first, let l = pts.last else { return }
                    p.move(to: CGPoint(x: f.x, y: g.size.height))
                    pts.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: l.x, y: g.size.height)); p.closeSubpath()
                }.fill(LinearGradient(colors: [color.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                Path { p in
                    for (i, pt) in pts.enumerated() { if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) } }
                }.stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var s: Store

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) { EnexisMark().frame(width: 28, height: 28); Text("Enexis AI Gateway").font(.system(size: 15, weight: .bold)) }
            }
            Section("Verbinding") {
                TextField("URL", text: $s.baseURLString, prompt: Text("https://gateway.example.com"))
                SecureField("API key", text: $s.draftKey, prompt: Text("sk-…"))
            }
            Section("Gedrag") {
                Picker("Verversen", selection: $s.interval) {
                    Text("15 sec").tag(15.0); Text("30 sec").tag(30.0); Text("1 min").tag(60.0); Text("5 min").tag(300.0)
                }
                Picker("Waarschuwing bij", selection: $s.alertAt) {
                    Text("50%").tag(0.5); Text("80%").tag(0.8); Text("90%").tag(0.9)
                }
                Picker("Menubalk toont", selection: $s.barStyle) {
                    Text("Bedrag").tag("amount"); Text("Percentage").tag("percent")
                    Text("Bedrag en %").tag("both"); Text("Alleen icoon").tag("icon")
                }
                Toggle("Meldingen", isOn: $s.notify)
                Toggle("Start bij inloggen", isOn: $s.loginItem).onChange(of: s.loginItem) { _, on in
                    do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {}
                }
            }
            Section {
                Button("Opslaan") { s.saveKey(s.draftKey); s.restart() }.keyboardShortcut(.defaultAction)
            } footer: {
                Text("De key staat in de Keychain en gaat alleen naar je gateway.").font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 560)
        .onAppear { s.draftKey = s.apiKey; s.loginItem = SMAppService.mainApp.status == .enabled }
    }
}


// MARK: - Enexis brand

enum Brand {
    static let pink = Color(red: 0xDF/255, green: 0x00/255, blue: 0x73/255)
    static let green = Color(red: 0xBD/255, green: 0xDB/255, blue: 0x00/255)
}

/// Enexis diamond (path data from enexis.nl logo): green diamond, pink half with white E.
struct EnexisMark: View {
    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width, size.height) / 6
            let ox = (size.width - 6 * k) / 2, oy = (size.height - 6 * k) / 2
            func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + CGFloat(x) * k, y: oy + CGFloat(y - 5) * k) }
            var g = Path(); g.move(to: P(3, 5)); g.addLine(to: P(0, 8)); g.addLine(to: P(3, 11)); g.addLine(to: P(6, 8)); g.closeSubpath()
            ctx.fill(g, with: .color(Brand.green))
            var m = Path()
            m.move(to: P(0, 8)); m.addLine(to: P(3, 5)); m.addLine(to: P(3.668, 5.668)); m.addLine(to: P(3.671, 6.602))
            m.addLine(to: P(2.31, 6.602)); m.addLine(to: P(2.31, 7.527)); m.addLine(to: P(3.672, 7.527)); m.addLine(to: P(3.675, 8.452))
            m.addLine(to: P(2.312, 8.452)); m.addLine(to: P(2.312, 9.376)); m.addLine(to: P(3.679, 9.376)); m.addLine(to: P(3.682, 10.318))
            m.addLine(to: P(3, 11)); m.closeSubpath()
            ctx.fill(m, with: .color(Brand.pink))
        }
    }
}

@MainActor func menuBarMark(status: Color?) -> NSImage {
    let content = ZStack(alignment: .bottomTrailing) {
        EnexisMark().frame(width: 18, height: 18)
        if let c = status {
            Circle().fill(c).frame(width: 7, height: 7)
                .overlay(Circle().stroke(Color.black.opacity(0.55), lineWidth: 1))
                .offset(x: 2, y: 2)
        }
    }.frame(width: 21, height: 20)
    let r = ImageRenderer(content: content)
    r.scale = 2
    let img = r.nsImage ?? NSImage()
    img.isTemplate = false
    return img
}
