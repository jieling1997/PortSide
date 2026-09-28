import Foundation

actor WebProbe {
    private var cache: [String: Bool] = [:]
    private var cachedAt: [String: Date] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 600) {
        self.ttl = ttl
    }

    func cachedResults(_ urls: [URL]) -> [String: Bool] {
        let now = Date()
        var results: [String: Bool] = [:]
        for url in urls {
            let key = url.absoluteString
            if let value = cache[key], let at = cachedAt[key], now.timeIntervalSince(at) < ttl {
                results[key] = value
            }
        }
        return results
    }

    func resolve(_ urls: [URL]) async -> [String: Bool] {
        let now = Date()
        var results = cachedResults(urls)
        let pending = urls.filter { results[$0.absoluteString] == nil }
        guard !pending.isEmpty else { return results }

        let probed = await withTaskGroup(of: (String, Bool).self) { group -> [(String, Bool)] in
            for url in pending {
                group.addTask { (url.absoluteString, await WebProbe.probe(url)) }
            }
            var collected: [(String, Bool)] = []
            for await item in group {
                collected.append(item)
            }
            return collected
        }

        for (key, value) in probed {
            cache[key] = value
            cachedAt[key] = now
            results[key] = value
        }
        return results
    }

    nonisolated static func probe(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.5
        request.setValue("Portside/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  let mime = http.mimeType?.lowercased() else {
                return false
            }
            return mime.contains("text/html") || mime.contains("xhtml")
        } catch {
            return false
        }
    }
}
