import Foundation

struct PortsCollector: ServiceCollector {
    let type: ServiceType = .port

    private struct Accumulator {
        var command: String
        var ports: Set<String>
    }

    func collect() async -> CollectorOutput {
        async let lsofRun = CommandRunner.run(tool: "lsof", arguments: ["-nP", "-iTCP", "-sTCP:LISTEN"])
        async let dockerRun = CommandRunner.run(tool: "docker", arguments: ["ps", "--format", "{{.Ports}}"])

        guard let result = await lsofRun else {
            return CollectorOutput(available: false, services: [], note: "lsof 不可用")
        }
        guard result.status == 0 || !result.stdout.isEmpty else {
            return CollectorOutput(available: false, services: [], note: "无法读取监听端口")
        }

        let dockerPorts = Self.publishedPorts(from: await dockerRun)

        var byPid: [String: Accumulator] = [:]
        for line in result.stdout.split(separator: "\n").dropFirst() {
            let tokens = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard tokens.count >= 9 else { continue }

            let command = Self.decodeEscapes(tokens[0])
            let pid = tokens[1]
            let namePart = tokens[8...].joined(separator: " ")
            guard let port = Self.parsePort(namePart), !dockerPorts.contains(port) else { continue }

            if byPid[pid] == nil {
                byPid[pid] = Accumulator(command: command, ports: [])
            }
            byPid[pid]?.ports.insert(port)
        }

        let resolved = await Self.resolveCommands(pids: Array(byPid.keys))

        let services = byPid.compactMap { pid, acc -> Service? in
            guard !acc.ports.isEmpty else { return nil }
            let listed = acc.ports.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
            let ports = listed.joined(separator: ", ")
            let url = listed.first.flatMap { URL(string: "http://localhost:\($0)") }
            let name = resolved[pid].map { Self.shortName(comm: $0.comm, args: $0.args) } ?? acc.command
            return Service(
                id: "port:\(pid)",
                type: .port,
                name: name,
                status: .running,
                detail: "端口 \(ports)",
                candidateURL: url
            )
        }
        return CollectorOutput(available: true, services: services, note: nil)
    }

    private static func resolveCommands(pids: [String]) async -> [String: (comm: String, args: String)] {
        guard !pids.isEmpty else { return [:] }
        let list = pids.joined(separator: ",")
        async let commRun = CommandRunner.run(tool: "ps", arguments: ["-p", list, "-o", "pid=,comm="])
        async let argsRun = CommandRunner.run(tool: "ps", arguments: ["-p", list, "-o", "pid=,args="])
        let (commResult, argsResult) = await (commRun, argsRun)

        var comms: [String: String] = [:]
        var arguments: [String: String] = [:]
        if let output = commResult?.stdout { parsePS(output, into: &comms) }
        if let output = argsResult?.stdout { parsePS(output, into: &arguments) }

        var resolved: [String: (comm: String, args: String)] = [:]
        for (pid, comm) in comms {
            resolved[pid] = (comm, arguments[pid] ?? comm)
        }
        return resolved
    }

    private static func parsePS(_ output: String, into dict: inout [String: String]) {
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let separator = trimmed.firstIndex(of: " ") else { continue }
            let pid = String(trimmed[..<separator])
            let value = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            guard !pid.isEmpty, !value.isEmpty else { continue }
            dict[pid] = value
        }
    }

    private static let interpreterPrefixes = ["python", "node", "ruby", "perl", "php", "java", "bun", "deno"]

    private static func shortName(comm: String, args: String) -> String {
        let base = executableBase(comm)
        let remainder = args.hasPrefix(comm)
            ? String(args.dropFirst(comm.count)).trimmingCharacters(in: .whitespaces)
            : args
        let tokens = remainder.split(separator: " ").map(String.init)
        let isInterpreter = interpreterPrefixes.contains { base.hasPrefix($0) }

        if isInterpreter, let first = tokens.first, !first.hasPrefix("-") {
            let script = (first as NSString).lastPathComponent
            if tokens.count >= 2, let sub = subcommand(tokens[1]) {
                return "\(script) \(sub)"
            }
            return script
        }

        if let first = tokens.first, let sub = subcommand(first) {
            return "\(base) \(sub)"
        }
        return base
    }

    private static func subcommand(_ token: String) -> String? {
        guard !token.hasPrefix("-"), !token.contains("/"), !token.contains("="), token.count <= 24 else {
            return nil
        }
        return token
    }

    private static func executableBase(_ comm: String) -> String {
        let trimmed = comm.trimmingCharacters(in: .whitespaces)
        let firstToken = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        if firstToken.hasSuffix(":") {
            return String(firstToken.dropLast())
        }
        if trimmed.contains("/") {
            return (trimmed as NSString).lastPathComponent
        }
        return trimmed
    }

    private static func publishedPorts(from result: CommandResult?) -> Set<String> {
        guard let result, result.status == 0 else { return [] }
        var ports: Set<String> = []
        for line in result.stdout.split(separator: "\n") {
            for mapping in line.split(separator: ",") {
                let part = mapping.trimmingCharacters(in: .whitespaces)
                guard let arrow = part.range(of: "->") else { continue }
                let host = part[..<arrow.lowerBound]
                guard let colon = host.lastIndex(of: ":") else { continue }
                let port = host[host.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if Int(port) != nil { ports.insert(String(port)) }
            }
        }
        return ports
    }

    private static func parsePort(_ raw: String) -> String? {
        var text = raw
        if let range = text.range(of: " (LISTEN)") {
            text = String(text[..<range.lowerBound])
        }
        guard let colon = text.lastIndex(of: ":") else { return nil }
        let port = String(text[text.index(after: colon)...])
        guard Int(port) != nil else { return nil }
        return port
    }

    private static func decodeEscapes(_ input: String) -> String {
        guard input.contains("\\x") else { return input }
        var result = ""
        let chars = Array(input)
        var i = 0
        while i < chars.count {
            if chars[i] == "\\", i + 3 < chars.count, chars[i + 1] == "x" {
                let hex = String(chars[(i + 2)...(i + 3)])
                if let value = UInt8(hex, radix: 16), let scalar = UnicodeScalar(UInt32(value)) {
                    result.unicodeScalars.append(scalar)
                    i += 4
                    continue
                }
            }
            result.append(chars[i])
            i += 1
        }
        return result
    }
}
