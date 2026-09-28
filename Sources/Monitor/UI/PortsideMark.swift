import SwiftUI

/// The same port-and-service mark used by the app icon, rendered in the current UI color.
struct PortsideMark: View {
    var color: Color = .primary

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            let offsetX = (size.width - 24 * scale) / 2
            let offsetY = (size.height - 24 * scale) / 2
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
            }

            var outline = Path()
            outline.move(to: point(9.2, 3.8))
            outline.addLine(to: point(6.9, 3.8))
            outline.addCurve(to: point(4.2, 6.5), control1: point(5.2, 3.8), control2: point(4.2, 4.8))
            outline.addLine(to: point(4.2, 17.5))
            outline.addCurve(to: point(6.9, 20.2), control1: point(4.2, 19.2), control2: point(5.2, 20.2))
            outline.addLine(to: point(9.2, 20.2))
            outline.move(to: point(14.8, 3.8))
            outline.addLine(to: point(17.1, 3.8))
            outline.addCurve(to: point(19.8, 6.5), control1: point(18.8, 3.8), control2: point(19.8, 4.8))
            outline.addLine(to: point(19.8, 17.5))
            outline.addCurve(to: point(17.1, 20.2), control1: point(19.8, 19.2), control2: point(18.8, 20.2))
            outline.addLine(to: point(14.8, 20.2))
            context.stroke(outline, with: .color(color), style: StrokeStyle(lineWidth: 2.6 * scale, lineCap: .round, lineJoin: .round))

            let dotRadius = 1.45 * scale
            let dotYs: [CGFloat] = [9, 15]
            for dotY in dotYs {
                let center = point(12, dotY)
                let dot = Path(ellipseIn: CGRect(x: center.x - dotRadius, y: center.y - dotRadius, width: 2 * dotRadius, height: 2 * dotRadius))
                context.fill(dot, with: .color(color))
            }
        }
        .frame(width: 26, height: 29)
        .accessibilityHidden(true)
    }
}
