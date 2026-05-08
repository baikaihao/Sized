import SwiftUI

struct RadialRingShape: Shape {
    var cornerRadius: CGFloat
    var thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        let outer: Path
        let inner: Path
        let inset = min(thickness, min(rect.width, rect.height) / 2)
        let innerRect = rect.insetBy(dx: inset, dy: inset)

        if cornerRadius >= min(rect.width, rect.height) / 2 - 2 {
            outer = Path(ellipseIn: rect)
            inner = Path(ellipseIn: innerRect)
        } else {
            outer = Path(roundedRect: rect, cornerRadius: min(cornerRadius, min(rect.width, rect.height) / 2))
            inner = Path(roundedRect: innerRect, cornerRadius: max(0, min(cornerRadius - inset / 2, min(innerRect.width, innerRect.height) / 2)))
        }

        var path = Path()
        path.addPath(outer)
        path.addPath(inner)
        return path
    }
}

struct DirectionSelectorSegmentShape: Shape {
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = hypot(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-angle - 22.5),
            endAngle: .degrees(-angle + 22.5),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
