import Foundation

enum ServiceType: String, CaseIterable, Identifiable, Sendable {
    case brew
    case docker
    case port

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .brew: "Homebrew"
        case .docker: "Docker"
        case .port: "监听端口"
        }
    }

}

enum ServiceStatus: Sendable {
    case running
    case stopped
    case error

    var sortRank: Int {
        switch self {
        case .running: 0
        case .error: 1
        case .stopped: 2
        }
    }
}

struct Service: Identifiable, Equatable, Sendable {
    let id: String
    let type: ServiceType
    let name: String
    let status: ServiceStatus
    var detail: String?
    var url: URL?
    var candidateURL: URL?
}

struct CollectorOutput: Sendable {
    var available: Bool
    var services: [Service]
    var note: String?

    static let unavailable = CollectorOutput(available: false, services: [], note: nil)
}
