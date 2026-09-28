import Foundation

enum CommandLineDump {
    static func run() {
        let collectors: [ServiceCollector] = [
            BrewCollector(),
            DockerCollector(),
            PortsCollector()
        ]
        let semaphore = DispatchSemaphore(value: 0)

        Task.detached {
            var collected: [(ServiceType, CollectorOutput)] = []
            for collector in collectors {
                collected.append((collector.type, await collector.collect()))
            }

            let candidates = Array(Set(collected.flatMap { $0.1.services.compactMap(\.candidateURL) }))
            let web = await WebProbe().resolve(candidates)

            for (type, output) in collected {
                let total = output.services.count
                let running = output.services.filter { $0.status == .running }.count
                print("== \(type.displayName)  available=\(output.available)  running=\(running)/\(total) ==")
                if let note = output.note {
                    print("   note: \(note)")
                }
                for service in output.services {
                    let detail = service.detail.map { " — \($0)" } ?? ""
                    var link = ""
                    if let candidate = service.candidateURL {
                        link = web[candidate.absoluteString] == true
                            ? "  ->  \(candidate.absoluteString)"
                            : "  (非网页: \(candidate.absoluteString))"
                    }
                    let status: String
                    switch service.status {
                    case .running: status = "run "
                    case .error: status = "err "
                    case .stopped: status = "stop"
                    }
                    print("   [\(status)] \(service.name)\(detail)\(link)")
                }
            }
            semaphore.signal()
        }

        semaphore.wait()
    }
}
