import Foundation

struct DockerCollector: ServiceCollector {
    let type: ServiceType = .docker

    private struct Entry: Decodable {
        let names: String
        let state: String
        let status: String
        let ports: String
        let image: String
        let health: String?

        enum CodingKeys: String, CodingKey {
            case names = "Names"
            case state = "State"
            case status = "Status"
            case ports = "Ports"
            case image = "Image"
            case health = "HealthStatus"
        }
    }

    func collect() async -> CollectorOutput {
        guard let result = await CommandRunner.run(tool: "docker", arguments: ["ps", "--format", "{{json .}}"]) else {
            return CollectorOutput(available: false, services: [], note: "未安装 Docker")
        }
        guard result.status == 0 else {
            return CollectorOutput(available: false, services: [], note: "Docker 未运行")
        }

        let decoder = JSONDecoder()
        var services: [Service] = []
        for line in result.stdout.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let entry = try? decoder.decode(Entry.self, from: data) else { continue }

            let status: ServiceStatus
            if entry.health == "unhealthy" {
                status = .error
            } else if entry.state == "running" {
                status = .running
            } else {
                status = .stopped
            }

            let ports = entry.ports.trimmingCharacters(in: .whitespaces)
            let detail = ports.isEmpty ? entry.image : "\(entry.image) · \(ports)"
            services.append(Service(
                id: "docker:\(entry.names)",
                type: .docker,
                name: entry.names,
                status: status,
                detail: detail,
                candidateURL: Self.webURL(from: ports)
            ))
        }
        return CollectorOutput(available: true, services: services, note: nil)
    }

    private static func webURL(from ports: String) -> URL? {
        for mapping in ports.split(separator: ",") {
            let part = mapping.trimmingCharacters(in: .whitespaces)
            guard let arrow = part.range(of: "->") else { continue }
            let hostPart = part[..<arrow.lowerBound]
            guard let colon = hostPart.lastIndex(of: ":") else { continue }
            let port = hostPart[hostPart.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard Int(port) != nil else { continue }
            return URL(string: "http://localhost:\(port)")
        }
        return nil
    }
}
