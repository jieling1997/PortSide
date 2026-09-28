import Foundation
import Observation

struct ServiceGroup: Identifiable, Sendable {
    let type: ServiceType
    let available: Bool
    let note: String?
    var services: [Service]

    var id: String { type.rawValue }

    var runningCount: Int {
        services.filter { $0.status == .running }.count
    }

    var errorCount: Int {
        services.filter { $0.status == .error }.count
    }
}

@MainActor
@Observable
final class ServiceMonitor {
    var groups: [ServiceGroup] = []
    var lastUpdated: Date?
    var isRefreshing = false

    let refreshInterval: TimeInterval
    private let collectors: [ServiceCollector]
    private let webProbe = WebProbe()
    private var timerTask: Task<Void, Never>?

    init(refreshInterval: TimeInterval = 15) {
        self.refreshInterval = refreshInterval
        self.collectors = [BrewCollector(), DockerCollector(), PortsCollector()]
    }

    var runningCount: Int {
        groups.reduce(0) { $0 + $1.runningCount }
    }

    var errorCount: Int {
        groups.reduce(0) { $0 + $1.errorCount }
    }

    func start() {
        guard timerTask == nil else { return }
        refresh()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.refreshInterval ?? 15
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { break }
                self?.refresh()
            }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            let collectors = self.collectors
            let outputs = await withTaskGroup(of: (ServiceType, CollectorOutput).self) { group in
                for collector in collectors {
                    group.addTask { (collector.type, await collector.collect()) }
                }
                var results: [ServiceType: CollectorOutput] = [:]
                for await (type, output) in group {
                    results[type] = output
                }
                return results
            }

            self.groups = ServiceType.allCases.map { type in
                let output = outputs[type] ?? .unavailable
                let sorted = output.services.sorted { lhs, rhs in
                    if lhs.status.sortRank != rhs.status.sortRank {
                        return lhs.status.sortRank < rhs.status.sortRank
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return ServiceGroup(type: type, available: output.available, note: output.note, services: sorted)
            }
            self.lastUpdated = Date()
            self.isRefreshing = false
            await self.applyCachedWebState()
        }
    }

    func probeWebServices() async {
        let candidates = Array(Set(groups.flatMap { $0.services.compactMap(\.candidateURL) }))
        guard !candidates.isEmpty else { return }
        let results = await webProbe.resolve(candidates)
        applyWebResults(results)
    }

    private func applyCachedWebState() async {
        let candidates = Array(Set(groups.flatMap { $0.services.compactMap(\.candidateURL) }))
        guard !candidates.isEmpty else { return }
        let results = await webProbe.cachedResults(candidates)
        guard !results.isEmpty else { return }
        applyWebResults(results)
    }

    private func applyWebResults(_ results: [String: Bool]) {
        for groupIndex in groups.indices {
            for serviceIndex in groups[groupIndex].services.indices {
                guard let candidate = groups[groupIndex].services[serviceIndex].candidateURL else { continue }
                groups[groupIndex].services[serviceIndex].url = results[candidate.absoluteString] == true ? candidate : nil
            }
        }
    }
}
