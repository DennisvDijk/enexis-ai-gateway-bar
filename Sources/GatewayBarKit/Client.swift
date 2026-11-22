import Foundation

struct APIError: Error, CustomStringConvertible {
    let status: Int
    let message: String
    var description: String { status == 0 ? message : "HTTP \(status)" }
}

/// Minimal LiteLLM proxy client. Tolerant JSON parsing: field sets differ per version/licence.
struct GatewayClient {
    let baseURL: URL
    let key: String
    nonisolated(unsafe) static var session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 15
        return URLSession(configuration: c)
    }()

    func get(_ path: String, query: [String: String] = [:], auth: Bool = true) async throws -> Any {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var req = URLRequest(url: comps.url!)
        if auth && !key.isEmpty { req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, resp) = try await Self.session.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else { throw APIError(status: code, message: String(data: data.prefix(200), encoding: .utf8) ?? "") }
            return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) ?? [:]
        } catch let e as APIError { throw e }
        catch { throw APIError(status: 0, message: error.localizedDescription) }
    }

    func modelIDs(healthyOnly: Bool) async throws -> [String] {
        let j = try await get("v1/models", query: healthyOnly ? ["healthy_only": "true"] : [:])
        let arr = (j as? [String: Any])?["data"] as? [[String: Any]] ?? []
        return arr.compactMap { $0["id"] as? String }
    }
}

func num(_ v: Any?) -> Double? {
    if let d = v as? Double { return d }
    if let i = v as? Int { return Double(i) }
    if let s = v as? String { return Double(s) }
    return nil
}
