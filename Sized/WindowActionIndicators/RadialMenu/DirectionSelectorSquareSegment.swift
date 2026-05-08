import SwiftUI

struct DirectionSelectorSquareSegment: Shape {
    var slot: RadialMenuSlot

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let size = max(rect.width, rect.height)
        let start = Angle(degrees: -slot.angleDegrees - 22.5)
        let end = Angle(degrees: -slot.angleDegrees + 22.5)

        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: size, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}
