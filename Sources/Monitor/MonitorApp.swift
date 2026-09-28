import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@main
struct PortsideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor: ServiceMonitor

    init() {
        if CommandLine.arguments.contains("--dump") {
            CommandLineDump.run()
            exit(0)
        }
        let monitor = ServiceMonitor()
        _monitor = State(initialValue: monitor)
        monitor.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(monitor: monitor)
        } label: {
            HStack(spacing: 3) {
                statusBarImage
                    .renderingMode(.template)
                    .foregroundStyle(monitor.errorCount > 0 ? Color.red : Color.primary)
                    .accessibilityLabel("Portside")
                if monitor.runningCount > 0 {
                    Text("\(monitor.runningCount)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var statusBarImage: Image {
        guard let url = Bundle.main.url(forResource: "PortsideStatusIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return Image(systemName: "network")
        }
        image.isTemplate = true
        image.size = NSSize(width: 22, height: 22)
        return Image(nsImage: image)
    }
}
