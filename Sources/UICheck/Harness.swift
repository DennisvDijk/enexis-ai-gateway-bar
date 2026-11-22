import AppKit
import SwiftUI
@testable import GatewayBarKit

// MARK: - Stub gateway (URLProtocol): no network, fully deterministic

final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Any))?
    nonisolated(unsafe) static var requests: [String] = []
    nonisolated(unsafe) static var auth: [String: String] = [:]
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        Self.requests.append(url.path + (url.query.map { "?" + $0 } ?? ""))
        Self.auth[url.path] = request.value(forHTTPHeaderField: "Authorization") ?? "none"
        let (code, body) = Self.handler?(request) ?? (404, [:])
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed])) ?? Data()
        let r = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: r, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

struct Gateway {
    var models = ["gpt-4o", "claude-sonnet"]
    var healthy: [String]? = nil          // nil = all healthy
    var alive = true
    var status = 200                      // status for authenticated endpoints
    var keyInfo: [String: Any] = ["spend": 4.2, "max_budget": 10, "key_alias": "mock", "budget_duration": "30d"]
    var teamInfo: [String: Any]? = nil
    var spendRows: [[String: Any]] = [["model": "gpt-4o", "spend": 1.5]]
    var month: Double? = 99.5

    func install() {
        StubProtocol.requests = []
        let g = self
        StubProtocol.handler = { req in
            let p = req.url!.path, q = req.url!.query ?? ""
            if p == "/health/liveliness" { return g.alive ? (200, "I'm alive!") : (503, [:]) }
            if p == "/health/readiness" { return (200, ["status": "healthy", "db": "connected"]) }
            if g.status != 200 { return (g.status, ["error": "nope"]) }
            switch p {
            case "/v1/models":
                let ids = q.contains("healthy_only") ? (g.healthy ?? g.models) : g.models
                return (200, ["data": ids.map { ["id": $0] }])
            case "/key/info":
                var info = g.keyInfo
                if g.teamInfo != nil { info["team_id"] = "t1" }
                return (200, ["info": info])
            case "/team/info": return g.teamInfo.map { (200, ["team_info": $0]) } ?? (404, [:])
            case "/spend/logs/v2": return (200, ["data": g.spendRows])
            case "/global/spend": return g.month.map { (200, ["spend": $0]) } ?? (403, [:])
            default: return (404, [:])
            }
        }
    }
}

// MARK: - Accessibility tree of a real hosted SwiftUI view

struct Node {
    let role: String, label: String, value: String, id: String
    let obj: NSObject
    var text: String { [label, value].filter { !$0.isEmpty }.joined(separator: " ") }
}

@MainActor final class Screen {
    let window: NSWindow
    let host: NSHostingView<AnyView>
    init<V: View>(_ view: V) {
        host = NSHostingView(rootView: AnyView(view))
        window = NSWindow(contentRect: NSRect(x: -3000, y: -3000, width: 10, height: 10), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.orderFront(nil)
    }
    deinit { MainActor.assumeIsolated { window.orderOut(nil) } }

    func nodes() -> [Node] {
        var out: [Node] = []
        func walk(_ e: Any, _ depth: Int) {
            guard depth < 40 else { return }
            if let o = e as? NSObject {
                func k(_ key: String) -> Any? { o.responds(to: Selector(key)) ? o.value(forKey: key) : nil }
                out.append(Node(role: (k("accessibilityRole") as? String) ?? "", label: (k("accessibilityLabel") as? String) ?? "",
                                value: k("accessibilityValue").map { "\($0)" } ?? "", id: (k("accessibilityIdentifier") as? String) ?? "", obj: o))
                for c in (k("accessibilityChildren") as? [Any]) ?? [] { walk(c, depth + 1) }
            }
        }
        walk(host, 0)
        return out
    }
    func texts() -> String { nodes().map(\.text).joined(separator: "\n") }
    func node(id: String) -> Node? { nodes().first { $0.id == id } }
    func node(label: String) -> Node? { nodes().first { $0.label == label } }
    @discardableResult func press(id: String) -> Bool { press(node(id: id)) }
    @discardableResult func press(label: String) -> Bool { press(node(label: label)) }
    private func press(_ n: Node?) -> Bool {
        guard let o = n?.obj, o.responds(to: Selector(("accessibilityPerformPress"))) else { return false }
        return o.perform(Selector(("accessibilityPerformPress"))) != nil
    }
}

// MARK: - Tiny test framework

@MainActor enum T {
    static var failures: [String] = []
    static var passed = 0
    static var current = ""
    static func check(_ ok: Bool, _ msg: @autoclosure () -> String, line: Int = #line) {
        if ok { passed += 1 } else { failures.append("[\(current)] line \(line): \(msg())") }
    }
    static func eq<X: Equatable>(_ a: X, _ b: X, _ what: String, line: Int = #line) { check(a == b, "\(what): expected \(b), got \(a)", line: line) }
    static func has(_ screen: Screen, _ s: String, line: Int = #line) { check(screen.texts().contains(s), "missing '\(s)'. Saw:\n\(screen.texts())", line: line) }
    static func hasNot(_ screen: Screen, _ s: String, line: Int = #line) { check(!screen.texts().contains(s), "unexpected '\(s)'", line: line) }
    static func run(_ name: String, _ body: () async -> Void) async { current = name; let before = failures.count; await body(); print((failures.count == before ? "  ✓ " : "  ✗ ") + name) }
}

@MainActor func freshStore(_ g: Gateway, key: String = "sk-test") -> Store {
    g.install()
    let s = Store()
    s.baseURLString = "http://stub.test"
    s.apiKey = key
    s.barStyle = "amount"; s.alertAt = 0.8; s.notify = false
    return s
}
