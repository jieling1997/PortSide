import AppKit
import SwiftUI

struct ServiceRow: View {
    let service: Service

    var body: some View {
        if let url = service.url {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                rowContent(showsLink: true)
            }
            .buttonStyle(.plain)
            .help("打开 \(url.absoluteString)")
        } else {
            rowContent(showsLink: false)
        }
    }

    private func rowContent(showsLink: Bool) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(service.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let detail = service.detail {
                Text(detail)
                    .font(detailFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if showsLink {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
            }

            if showsStatus {
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .frame(minHeight: 28)
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        switch service.status {
        case .running: .green
        case .error: .red
        case .stopped: .gray.opacity(0.5)
        }
    }

    private var statusText: String {
        switch service.status {
        case .running: "运行中"
        case .error: "异常"
        case .stopped: "已停止"
        }
    }

    private var showsStatus: Bool {
        switch service.type {
        case .port: false
        case .brew, .docker: true
        }
    }

    private var detailFont: Font {
        switch service.type {
        case .port: .system(size: 11, design: .monospaced)
        case .brew, .docker: .system(size: 11)
        }
    }
}
