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
    var centerSize: Double
    var centerCornerRadius: Double
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
        centerSize: 44,
        centerCornerRadius: 22,
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

extension WheelStyleSettings {
    private enum CodingKeys: String, CodingKey {
        case isVisible
        case size
        case thickness
        case cornerRadius
        case centerSize
        case centerCornerRadius
        case lockToScreenCenter
        case hideWhenNoSelection
        case appearanceAnimation
        case sizeAnimation
        case angleAnimation
        case accentColorMode
        case primaryColorHex
        case useGradient
        case secondaryColorHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? Self.default.isVisible
        size = try container.decodeIfPresent(Double.self, forKey: .size) ?? Self.default.size
        thickness = try container.decodeIfPresent(Double.self, forKey: .thickness) ?? Self.default.thickness
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? Self.default.cornerRadius

        let legacyCenterSize = max(44, size - thickness * 2 - 6)
        centerSize = try container.decodeIfPresent(Double.self, forKey: .centerSize) ?? legacyCenterSize
        centerCornerRadius = try container.decodeIfPresent(Double.self, forKey: .centerCornerRadius) ?? centerSize / 2

        lockToScreenCenter = try container.decodeIfPresent(Bool.self, forKey: .lockToScreenCenter) ?? Self.default.lockToScreenCenter
        hideWhenNoSelection = try container.decodeIfPresent(Bool.self, forKey: .hideWhenNoSelection) ?? Self.default.hideWhenNoSelection
        appearanceAnimation = try container.decodeIfPresent(Bool.self, forKey: .appearanceAnimation) ?? Self.default.appearanceAnimation
        sizeAnimation = try container.decodeIfPresent(RadialAnimationStyle.self, forKey: .sizeAnimation) ?? Self.default.sizeAnimation
        angleAnimation = try container.decodeIfPresent(RadialAnimationStyle.self, forKey: .angleAnimation) ?? Self.default.angleAnimation
        accentColorMode = try container.decodeIfPresent(AccentColorMode.self, forKey: .accentColorMode) ?? Self.default.accentColorMode
        primaryColorHex = try container.decodeIfPresent(String.self, forKey: .primaryColorHex) ?? Self.default.primaryColorHex
        useGradient = try container.decodeIfPresent(Bool.self, forKey: .useGradient) ?? Self.default.useGradient
        secondaryColorHex = try container.decodeIfPresent(String.self, forKey: .secondaryColorHex) ?? Self.default.secondaryColorHex
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encode(size, forKey: .size)
        try container.encode(thickness, forKey: .thickness)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(centerSize, forKey: .centerSize)
        try container.encode(centerCornerRadius, forKey: .centerCornerRadius)
        try container.encode(lockToScreenCenter, forKey: .lockToScreenCenter)
        try container.encode(hideWhenNoSelection, forKey: .hideWhenNoSelection)
        try container.encode(appearanceAnimation, forKey: .appearanceAnimation)
        try container.encode(sizeAnimation, forKey: .sizeAnimation)
        try container.encode(angleAnimation, forKey: .angleAnimation)
        try container.encode(accentColorMode, forKey: .accentColorMode)
        try container.encode(primaryColorHex, forKey: .primaryColorHex)
        try container.encode(useGradient, forKey: .useGradient)
        try container.encode(secondaryColorHex, forKey: .secondaryColorHex)
    }
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
