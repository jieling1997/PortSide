import Foundation

struct BrewCollector: ServiceCollector {
    let type: ServiceType = .brew

    private struct Entry: Decodable {
        let name: String
        let status: String
        let user: String?
        let exitCode: Int?

        enum CodingKeys: String, CodingKey {
            case name, status, user
            case exitCode = "exit_code"
        }
    }

    func collect() async -> CollectorOutput {
        guard let result = await CommandRunner.run(tool: "brew", arguments: ["services", "list", "--json"]) else {
            return CollectorOutput(available: false, services: [], note: "未安装 Homebrew")
        }
        guard result.status == 0, let data = result.stdout.data(using: .utf8) else {
            return CollectorOutput(available: false, services: [], note: "Homebrew 不可用")
        }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return CollectorOutput(available: true, services: [], note: "无法解析 brew 输出")
        }

        let services = entries.map { entry -> Service in
            let status: ServiceStatus
            switch entry.status {
            case "started": status = .running
            case "error": status = .error
            default: status = .stopped
            }
            var detail: String?
            if status == .error, let code = entry.exitCode {
                detail = "退出码 \(code)"
            } else if status == .running, let user = entry.user {
                detail = "用户 \(user)"
            }
            return Service(id: "brew:\(entry.name)", type: .brew, name: entry.name, status: status, detail: detail)
        }
        return CollectorOutput(available: true, services: services, note: nil)
    }
}
