import Foundation
import SwiftUI

enum RadialMenuSlot: String, CaseIterable, Codable, Identifiable {
    case topLeft
    case top
    case topRight
    case left
    case center
    case right
    case bottomLeft
    case bottom
    case bottomRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topLeft: "左上"
        case .top: "上"
        case .topRight: "右上"
        case .left: "左"
        case .center: "中心"
        case .right: "右"
        case .bottomLeft: "左下"
        case .bottom: "下"
        case .bottomRight: "右下"
        }
    }

    var shortName: String {
        switch self {
        case .topLeft: "左上"
        case .top: "上"
        case .topRight: "右上"
        case .left: "左"
        case .center: "中"
        case .right: "右"
        case .bottomLeft: "左下"
        case .bottom: "下"
        case .bottomRight: "右下"
        }
    }

    var systemImage: String {
        switch self {
        case .topLeft: "arrow.up.left"
        case .top: "arrow.up"
        case .topRight: "arrow.up.right"
        case .left: "arrow.left"
        case .center: "circle"
        case .right: "arrow.right"
        case .bottomLeft: "arrow.down.left"
        case .bottom: "arrow.down"
        case .bottomRight: "arrow.down.right"
        }
    }

    var angleDegrees: Double {
        switch self {
        case .right: 0
        case .topRight: 45
        case .top: 90
        case .topLeft: 135
        case .left: 180
        case .bottomLeft: 225
        case .bottom: 270
        case .bottomRight: 315
        case .center: 0
        }
    }

    var gridColumn: Int {
        switch self {
        case .topLeft, .left, .bottomLeft: 0
        case .top, .center, .bottom: 1
        case .topRight, .right, .bottomRight: 2
        }
    }

    var gridRow: Int {
        switch self {
        case .topLeft, .top, .topRight: 0
        case .left, .center, .right: 1
        case .bottomLeft, .bottom, .bottomRight: 2
        }
    }

    var offsetUnit: CGSize {
        switch self {
        case .topLeft: CGSize(width: -1, height: -1)
        case .top: CGSize(width: 0, height: -1)
        case .topRight: CGSize(width: 1, height: -1)
        case .left: CGSize(width: -1, height: 0)
        case .center: .zero
        case .right: CGSize(width: 1, height: 0)
        case .bottomLeft: CGSize(width: -1, height: 1)
        case .bottom: CGSize(width: 0, height: 1)
        case .bottomRight: CGSize(width: 1, height: 1)
        }
    }

    static let visualOrder: [RadialMenuSlot] = [
        .topLeft, .top, .topRight,
        .left, .center, .right,
        .bottomLeft, .bottom, .bottomRight
    ]

    static let directional: [RadialMenuSlot] = [
        .right, .topRight, .top, .topLeft, .left, .bottomLeft, .bottom, .bottomRight
    ]

    static func nearestSlot(delta: CGSize, directionalThreshold: CGFloat, noActionThreshold: CGFloat) -> RadialMenuSlot? {
        let distance = hypot(delta.width, delta.height)
        guard distance >= noActionThreshold else { return nil }
        guard distance >= directionalThreshold else { return .center }

        let radians = atan2(-delta.height, delta.width)
        var degrees = radians * 180 / .pi
        if degrees < 0 { degrees += 360 }

        let index = Int(((degrees + 22.5) / 45).rounded(.down)) % directional.count
        return directional[index]
    }
}
