import Foundation
import SwiftUI
import UserNotifications
import ServiceManagement

enum Health: String { case unknown, ok, degraded, down, authError }

struct ModelStatus: Identifiable, Hashable {
    var id: String
    var available: Bool
    var spendToday: Double
}

struct BudgetInfo {
    var spend: Double
    var maxBudget: Double?
    var resetAt: Date?
    var duration: String?
    var alias: String?
    var rpm: Double?
    var tpm: Double?
    var period: String? {
        guard let d = duration?.lowercased(), !d.isEmpty else { return nil }
        switch d {
        case "1d", "24h": return "dagelijks"
        case "7d", "1w", "168h": return "wekelijks"
        case "30d", "1mo", "720h": return "maandelijks"
        default: return d
        }
    }
    var fraction: Double? { maxBudget.flatMap { $0 > 0 ? spend / $0 : nil } }
}

struct TeamInfo { var name: String; var spend: Double; var max: Double?; var duration: String?; var resetAt: Date? }

@MainActor
final class Store: ObservableObject {
    static let shared = Store()
    @AppStorage("barStyle") var barStyle = "amount"   // amount | percent | both | icon
    @AppStorage("baseURL") var baseURLString = "http://localhost:4000"
    @AppStorage("interval") var interval = 60.0
    @AppStorage("alertAt") var alertAt = 0.8
    @AppStorage("notify") var notify = true
    @Published var apiKey: String = Keychain.get()

    @Published var health: Health = .unknown
    @Published var readiness = ""
    @Published var models: [ModelStatus] = []
    @Published var budget: BudgetInfo?
    @Published var spendToday: Double?
    @Published var spendMonth: Double?
    @Published var team: TeamInfo?
    @Published var lastUpdate: Date?
    @Published var lastError: String?
    @Published var refreshing = false
    @Published var showAll = false
    @Published var draftKey = ""
    @Published var loginItem = false
    @Published var history: [Double] = []   // spend samples for sparkline

    private var task: Task<Void, Never>?
    private var knownModels: Set<String>?
    private var knownUnavailable: Set<String> = []
    private var alerted: Set<String> = []
    private var started = false

    func saveKey(_ k: String) { apiKey = k; Keychain.set(k) }

    func start() {
        guard !started else { return }
        started = true
        if Bundle.main.bundleIdentifier != nil { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }
        restart()
    }
    func restart() {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let s = max(15, self?.interval ?? 60)
                try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000))
            }
        }
    }

    var title: String {
        if health == .authError { return "key?" }
        if health == .down { return "offline" }
        let amount = budget?.spend ?? spendToday
        let pct = budget?.fraction.map { "\(Int($0 * 100))%" }
        switch barStyle {
        case "icon": return ""
        case "percent": return pct ?? amount.map { String(format: "$%.0f", $0) } ?? "–"
        case "both":
            guard let a = amount else { return "–" }
            return pct.map { String(format: "$%.0f · ", a) + $0 } ?? String(format: "$%.2f", a)
        default: return amount.map { $0 >= 100 ? String(format: "$%.0f", $0) : String(format: "$%.2f", $0) } ?? "–"
        }
    }
    var symbol: String {
        switch health {
        case .ok: return "sparkle"
        case .degraded: return "exclamationmark.triangle.fill"
        case .down: return "wifi.slash"
        case .authError: return "key.slash"
        case .unknown: return "circle.dashed"
        }
    }
    var statusLine: String {
        switch health {
        case .ok: return "Alles operationeel"
        case .degraded:
            let n = models.filter { !$0.available }.count
            return n == 1 ? "1 model onbeschikbaar" : "\(n) modellen onbeschikbaar"
        case .down: return "Gateway niet bereikbaar"
        case .authError: return "Key geweigerd"
        case .unknown: return lastError ?? "Nog niet ingesteld"
        }
    }
    var badge: Color? { health == .unknown ? nil : tint }
    var tint: Color {
        switch health { case .ok: return .green; case .degraded: return .orange; case .down, .authError: return .red; case .unknown: return .gray }
    }

    func refresh() async {
        guard let url = URL(string: baseURLString.trimmingCharacters(in: .whitespaces)), url.host != nil else {
            lastError = "Ongeldige gateway-URL"; health = .unknown; return
        }
        refreshing = true; defer { refreshing = false }
        let c = GatewayClient(baseURL: url, key: apiKey)
        lastError = nil

        // 1. Liveness / readiness (no auth, no tokens)
        do {
            _ = try await c.get("health/liveliness", auth: false)
            if let r = try? await c.get("health/readiness", auth: false) as? [String: Any] {
                readiness = "\(r["status"] ?? "?") · db \(r["db"] ?? "?")"
            }
        } catch {
            health = .down; lastError = "Gateway niet bereikbaar: \(error)"; lastUpdate = Date(); return
        }

        // 2. Models: full list vs healthy-only list (cached background health checks)
        var authFailed = false
        do {
            let all = try await c.modelIDs(healthyOnly: false)
            let healthy = (try? await c.modelIDs(healthyOnly: true)) ?? all
            let healthySet = Set(healthy)
            let spendBy = (try? await spendByModelToday(c)) ?? [:]
            models = all.sorted().map { ModelStatus(id: $0, available: healthySet.contains($0), spendToday: spendBy[$0] ?? 0) }
            spendToday = spendBy.isEmpty ? spendToday : spendBy.values.reduce(0, +)
            diffModels(Set(all), unavailable: Set(all).subtracting(healthySet))
        } catch let e as APIError where e.status == 401 || e.status == 403 {
            authFailed = true
        } catch { lastError = "Modellen: \(error)" }

        // 3. Budget / spend for the caller's key
        do {
            if let j = try await c.get("key/info") as? [String: Any], let i = j["info"] as? [String: Any] {
                let b = BudgetInfo(spend: num(i["spend"]) ?? 0, maxBudget: num(i["max_budget"]),
                                   resetAt: parseDate(i["budget_reset_at"] as? String),
                                   duration: i["budget_duration"] as? String, alias: i["key_alias"] as? String,
                                   rpm: num(i["rpm_limit"]), tpm: num(i["tpm_limit"]))
                budget = b
                history = Array((history + [b.spend]).suffix(60))
                checkBudget(b)
                if let tid = i["team_id"] as? String, let tj = try? await c.get("team/info", query: ["team_id": tid]) as? [String: Any],
                   let ti = tj["team_info"] as? [String: Any] {
                    let t = TeamInfo(name: ti["team_alias"] as? String ?? tid, spend: num(ti["spend"]) ?? 0, max: num(ti["max_budget"]),
                                     duration: ti["budget_duration"] as? String, resetAt: parseDate(ti["budget_reset_at"] as? String))
                    team = t
                    // No budget on the key itself: use the team's budget (spend, limit and period)
                    if b.maxBudget == nil, let m = t.max {
                        let tb = BudgetInfo(spend: t.spend, maxBudget: m, resetAt: t.resetAt, duration: t.duration, alias: b.alias, rpm: b.rpm, tpm: b.tpm)
                        budget = tb; checkBudget(tb)
                    }
                }
            }
        } catch let e as APIError where e.status == 401 || e.status == 403 { authFailed = true }
        catch { lastError = (lastError.map { $0 + " · " } ?? "") + "Budget: \(error)" }

        // 4. Month-to-date (needs admin/spend permission; silently skipped otherwise)
        spendMonth = try? await monthSpend(c)

        let down = models.filter { !$0.available }.count
        health = authFailed && models.isEmpty && budget == nil ? .authError : (down > 0 ? .degraded : .ok)
        lastUpdate = Date()
    }

    // MARK: spend

    private func utcString(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC"); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: d)
    }

    private func spendByModelToday(_ c: GatewayClient) async throws -> [String: Double] {
        let start = Calendar.current.startOfDay(for: Date())
        var out: [String: Double] = [:]
        for page in 1...10 {
            let j = try await c.get("spend/logs/v2", query: ["start_date": utcString(start), "end_date": utcString(Date().addingTimeInterval(60)),
                                                             "page": "\(page)", "page_size": "1000", "exclude_internal_health_checks": "true"])
            let rows = (j as? [String: Any])?["data"] as? [[String: Any]] ?? []
            if rows.isEmpty { break }
            for r in rows { out[(r["model"] as? String) ?? "?", default: 0] += num(r["spend"]) ?? 0 }
            if rows.count < 1000 { break }
        }
        return out
    }

    private func monthSpend(_ c: GatewayClient) async throws -> Double? {
        let j = try await c.get("global/spend") as? [String: Any]
        return num(j?["spend"])
    }

    private func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    // MARK: alerts

    private func diffModels(_ all: Set<String>, unavailable: Set<String>) {
        defer { knownModels = all; knownUnavailable = unavailable }
        guard let prev = knownModels else { return }
        let added = all.subtracting(prev), removed = prev.subtracting(all)
        let newlyDown = unavailable.subtracting(knownUnavailable).intersection(all)
        let recovered = knownUnavailable.subtracting(unavailable).intersection(all)
        if !added.isEmpty { post("Nieuwe modellen", added.sorted().joined(separator: ", ")) }
        if !removed.isEmpty { post("Modellen verdwenen", removed.sorted().joined(separator: ", ")) }
        if !newlyDown.isEmpty { post("Model onbeschikbaar", newlyDown.sorted().joined(separator: ", ")) }
        if !recovered.isEmpty { post("Model weer beschikbaar", recovered.sorted().joined(separator: ", ")) }
    }

    private func checkBudget(_ b: BudgetInfo) {
        guard let f = b.fraction else { return }
        let tag = "\(b.resetAt?.timeIntervalSince1970 ?? 0)"
        if f >= 1, alerted.insert("100-\(tag)").inserted { post("Budget op", String(format: "$%.2f van $%.2f verbruikt", b.spend, b.maxBudget ?? 0)) }
        else if f >= alertAt, f < 1, alerted.insert("soft-\(tag)").inserted { post("Budget \(Int(f * 100))%", String(format: "$%.2f van $%.2f", b.spend, b.maxBudget ?? 0)) }
    }

    private func post(_ title: String, _ body: String) {
        guard notify, Bundle.main.bundleIdentifier != nil else { return }
        let c = UNMutableNotificationContent(); c.title = title; c.body = body; c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }
}
