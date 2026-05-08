import Foundation
import SwiftUI

enum AccentColorMode: String, CaseIterable, Codable, Identifiable {
    case system
    case wallpaper
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "系统"
        case .wallpaper: "壁纸提取"
        case .custom: "自定义"
        }
    }
}

enum RadialAnimationStyle: String, CaseIterable, Codable, Identifiable {
    case none
    case smooth
    case spring

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "无动画"
        case .smooth: "平滑"
        case .spring: "弹性"
        }
    }
}

enum ConfirmationMode: String, CaseIterable, Codable, Identifiable {
    case release
    case click

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .release: "松开触发键"
        case .click: "点击确认"
        }
    }
}

enum ResizeAnchor: String, CaseIterable, Codable, Identifiable {
    case currentCenter
    case topLeft

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .currentCenter: "保持当前中心"
        case .topLeft: "保持左上角"
        }
    }
}

struct WheelStyleSettings: Codable, Equatable {
    var isVisible: Bool
    var size: Double
    var thickness: Double
    var cornerRadius: Double
    var lockToScreenCenter: Bool
    var hideWhenNoSelection: Bool
    var appearanceAnimation: Bool
    var sizeAnimation: RadialAnimationStyle
    var angleAnimation: RadialAnimationStyle
    var accentColorMode: AccentColorMode
    var primaryColorHex: String
    var useGradient: Bool
    var secondaryColorHex: String

    static let `default` = WheelStyleSettings(
        isVisible: true,
        size: 100,
        thickness: 30,
        cornerRadius: 50,
        lockToScreenCenter: false,
        hideWhenNoSelection: false,
        appearanceAnimation: true,
        sizeAnimation: .smooth,
        angleAnimation: .spring,
        accentColorMode: .system,
        primaryColorHex: "#0A84FF",
        useGradient: false,
        secondaryColorHex: "#5E5CE6"
    )
}

struct TriggerSettings: Codable, Equatable {
    var triggerKeyDisplayName: String
    var triggerDelayMilliseconds: Double
    var doubleTapTrigger: Bool
    var middleClickTrigger: Bool
    var timeoutSeconds: Double

    static let `default` = TriggerSettings(
        triggerKeyDisplayName: "右⌥",
        triggerDelayMilliseconds: 0,
        doubleTapTrigger: false,
        middleClickTrigger: true,
        timeoutSeconds: 5
    )
}

struct BehaviorSettings: Codable, Equatable {
    var confirmationMode: ConfirmationMode
    var resizeAnimation: Bool
    var resizeAnchor: ResizeAnchor
    var ignoreFullScreenWindows: Bool
    var showPreview: Bool
    var previewPadding: Double
    var previewCornerRadius: Double
    var previewBorderWidth: Double
    var previewBorderColorHex: String
    var hapticFeedback: Bool

    static let `default` = BehaviorSettings(
        confirmationMode: .release,
        resizeAnimation: true,
        resizeAnchor: .currentCenter,
        ignoreFullScreenWindows: true,
        showPreview: true,
        previewPadding: 8,
        previewCornerRadius: 12,
        previewBorderWidth: 2,
        previewBorderColorHex: "#0A84FF",
        hapticFeedback: true
    )
}

struct GeneralSettings: Codable, Equatable {
    var launchAtLogin: Bool
    var showMenuBarIcon: Bool
    var hideDockIcon: Bool

    static let `default` = GeneralSettings(
        launchAtLogin: false,
        showMenuBarIcon: true,
        hideDockIcon: false
    )
}

struct AssignmentSettings: Codable, Equatable {
    var actions: [RadialMenuSlot: RadialMenuAction]

    subscript(slot: RadialMenuSlot) -> RadialMenuAction {
        get { actions[slot] ?? Self.defaultAction(for: slot) }
        set { actions[slot] = newValue }
    }

    static let `default` = AssignmentSettings(actions: Dictionary(uniqueKeysWithValues: RadialMenuSlot.allCases.map { ($0, defaultAction(for: $0)) }))

    static func defaultAction(for slot: RadialMenuSlot) -> RadialMenuAction {
        switch slot {
        case .top: RadialMenuAction(kind: .presentation)
        case .bottom: RadialMenuAction(kind: .compact)
        case .left: RadialMenuAction(kind: .medium)
        case .right: RadialMenuAction(kind: .large)
        case .topLeft: RadialMenuAction(kind: .small)
        case .topRight: RadialMenuAction(kind: .wide)
        case .bottomLeft: RadialMenuAction(kind: .mobilePortrait)
        case .bottomRight: RadialMenuAction(kind: .tabletLandscape)
        case .center: RadialMenuAction(kind: .browser)
        }
    }
}

struct AppSettingsSnapshot: Codable, Equatable {
    var wheelStyle: WheelStyleSettings
    var assignments: AssignmentSettings
    var trigger: TriggerSettings
    var behavior: BehaviorSettings
    var general: GeneralSettings

    static let `default` = AppSettingsSnapshot(
        wheelStyle: .default,
        assignments: .default,
        trigger: .default,
        behavior: .default,
        general: .default
    )
}
