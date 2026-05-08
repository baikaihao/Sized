import SwiftUI

struct DirectionSelectorCircleSegment: Shape {
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
