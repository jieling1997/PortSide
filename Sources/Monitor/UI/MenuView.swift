import AppKit
import SwiftUI

struct MenuView: View {
    let monitor: ServiceMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            summary
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(monitor.groups.indices, id: \.self) { index in
                        let group = monitor.groups[index]
                        groupSection(group)
                        if index < monitor.groups.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
            .scrollIndicators(.hidden)
            .frame(height: listHeight)
            Divider()
            footer
        }
        .frame(width: 320)
        .task {
            monitor.refresh()
            await monitor.probeWebServices()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            PortsideMark(color: .blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Portside")
                    .font(.system(size: 15, weight: .semibold))
                Text(lastUpdatedText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if monitor.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var summary: some View {
        HStack(spacing: 5) {
            Text("\(monitor.runningCount) 项运行中")
                .font(.system(size: 13, weight: .semibold))
            Text("·")
                .foregroundStyle(.tertiary)
            Text("\(monitor.errorCount) 项异常")
                .foregroundStyle(monitor.errorCount > 0 ? Color.red : Color.secondary)
            Spacer(minLength: 0)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var listHeight: CGFloat {
        guard !monitor.groups.isEmpty else { return 120 }
        var height: CGFloat = 0
        for group in monitor.groups {
            height += 32
            if !group.available || group.services.isEmpty {
                height += 24
            } else {
                height += CGFloat(group.services.count) * 28
            }
            if group.note != nil { height += 15 }
        }
        return min(max(height, 120), 400)
    }

    @ViewBuilder
    private func groupSection(_ group: ServiceGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Text(group.type.displayName)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                if group.available {
                    Text(groupCountText(group))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 7)

            if !group.available {
                placeholder(group.note ?? "不可用")
                    .padding(.bottom, 7)
            } else if group.services.isEmpty {
                placeholder(group.note ?? "无运行中的服务")
                    .padding(.bottom, 7)
            } else {
                ForEach(group.services) { service in
                    ServiceRow(service: service)
                }
                if let note = group.note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 3)
                        .padding(.bottom, 6)
                }
            }
        }
    }

    private func groupCountText(_ group: ServiceGroup) -> String {
        switch group.type {
        case .port: "\(group.services.count)"
        case .brew, .docker: "\(group.runningCount)/\(group.services.count)"
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            footerButton("刷新", systemImage: "arrow.clockwise") {
                monitor.refresh()
            }
            Divider()
                .padding(.leading, 26)
            footerButton("退出", systemImage: "rectangle.portrait.and.arrow.right") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    private func footerButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12))
                Spacer(minLength: 0)
            }
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var lastUpdatedText: String {
        guard let date = monitor.lastUpdated else { return "等待刷新" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date()) + "已更新"
    }
}
