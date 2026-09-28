import Foundation

struct CommandResult: Sendable {
    let status: Int32
    let stdout: String
    let stderr: String
}

enum CommandRunner {
    static func run(tool: String, arguments: [String]) async -> CommandResult? {
        await run(executable: "/usr/bin/env", arguments: [tool] + arguments)
    }

    static func run(executable: String, arguments: [String]) async -> CommandResult? {
        await withCheckedContinuation { (continuation: CheckedContinuation<CommandResult?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                var environment = ProcessInfo.processInfo.environment
                let preferred = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
                let current = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
                environment["PATH"] = (preferred + current).joined(separator: ":")
                process.environment = environment

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }

                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                continuation.resume(returning: CommandResult(
                    status: process.terminationStatus,
                    stdout: String(decoding: outData, as: UTF8.self),
                    stderr: String(decoding: errData, as: UTF8.self)
                ))
            }
        }
    }
}

protocol ServiceCollector: Sendable {
    var type: ServiceType { get }
    func collect() async -> CollectorOutput
}
