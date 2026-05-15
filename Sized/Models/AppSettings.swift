import Foundation
import SwiftUI

enum AccentColorMode: String, CaseIterable, Codable, Identifiable {
    case system
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "系统".localized
        case .custom: "自定义".localized
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
        case .none: "无动画".localized
        case .smooth: "平滑".localized
        case .spring: "弹性".localized
        }
    }
}

enum ConfirmationMode: String, CaseIterable, Codable, Identifiable {
    case release
    case click

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .release: "松开触发键".localized
        case .click: "点击确认".localized
        }
    }
}

enum ResizeAnchor: String, CaseIterable, Codable, Identifiable {
    case currentCenter
    case topLeft

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .currentCenter: "保持当前中心".localized
        case .topLeft: "保持左上角".localized
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

enum OptionSide: String, CaseIterable, Codable, Identifiable {
    case left
    case right
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: "左侧 Option".localized
        case .right: "右侧 Option".localized
        case .both: "两侧 Option".localized
        }
    }
}

struct TriggerSettings: Codable, Equatable {
    var triggerKeyDisplayName: String
    var useOptionAsTrigger: Bool
    var optionSide: OptionSide
    var triggerDelayMilliseconds: Double
    var doubleTapTrigger: Bool
    var middleClickTrigger: Bool
    var timeoutSeconds: Double

    static let `default` = TriggerSettings(
        triggerKeyDisplayName: "⌃E",
        useOptionAsTrigger: false,
        optionSide: .right,
        triggerDelayMilliseconds: 0,
        doubleTapTrigger: false,
        middleClickTrigger: true,
        timeoutSeconds: 5
    )
}

extension TriggerSettings {
    private enum CodingKeys: String, CodingKey {
        case triggerKeyDisplayName
        case useOptionAsTrigger
        case optionSide
        case triggerDelayMilliseconds
        case doubleTapTrigger
        case middleClickTrigger
        case timeoutSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        triggerKeyDisplayName = try container.decodeIfPresent(String.self, forKey: .triggerKeyDisplayName) ?? Self.default.triggerKeyDisplayName
        useOptionAsTrigger = try container.decodeIfPresent(Bool.self, forKey: .useOptionAsTrigger) ?? Self.default.useOptionAsTrigger
        optionSide = try container.decodeIfPresent(OptionSide.self, forKey: .optionSide) ?? Self.default.optionSide
        triggerDelayMilliseconds = try container.decodeIfPresent(Double.self, forKey: .triggerDelayMilliseconds) ?? Self.default.triggerDelayMilliseconds
        doubleTapTrigger = try container.decodeIfPresent(Bool.self, forKey: .doubleTapTrigger) ?? Self.default.doubleTapTrigger
        middleClickTrigger = try container.decodeIfPresent(Bool.self, forKey: .middleClickTrigger) ?? Self.default.middleClickTrigger
        timeoutSeconds = try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? Self.default.timeoutSeconds
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(triggerKeyDisplayName, forKey: .triggerKeyDisplayName)
        try container.encode(useOptionAsTrigger, forKey: .useOptionAsTrigger)
        try container.encode(optionSide, forKey: .optionSide)
        try container.encode(triggerDelayMilliseconds, forKey: .triggerDelayMilliseconds)
        try container.encode(doubleTapTrigger, forKey: .doubleTapTrigger)
        try container.encode(middleClickTrigger, forKey: .middleClickTrigger)
        try container.encode(timeoutSeconds, forKey: .timeoutSeconds)
    }
}

struct BehaviorSettings: Codable, Equatable {
    var confirmationMode: ConfirmationMode
    var resizeAnimation: Bool
    var resizeAnimationDuration: Double
    var resizeAnchor: ResizeAnchor
    var ignoreFullScreenWindows: Bool
    var showPreview: Bool
    var previewPadding: Double
    var previewCornerRadius: Double
    var previewBorderWidth: Double
    var previewBorderColorHex: String
    var previewBackgroundColorHex: String
    var previewAnimationSpeed: Double
    var hapticFeedback: Bool
    var escapeCancelsRadial: Bool
    var rightClickCancelsRadial: Bool
    var resizeDiagnostics: Bool

    static let `default` = BehaviorSettings(
        confirmationMode: .release,
        resizeAnimation: true,
        resizeAnimationDuration: 0.16,
        resizeAnchor: .currentCenter,
        ignoreFullScreenWindows: true,
        showPreview: true,
        previewPadding: 8,
        previewCornerRadius: 12,
        previewBorderWidth: 2,
        previewBorderColorHex: "#0A84FF",
        previewBackgroundColorHex: "#0A84FF",
        previewAnimationSpeed: 0.2,
        hapticFeedback: true,
        escapeCancelsRadial: true,
        rightClickCancelsRadial: true,
        resizeDiagnostics: false
    )
}

extension BehaviorSettings {
    private enum CodingKeys: String, CodingKey {
        case confirmationMode
        case resizeAnimation
        case resizeAnimationDuration
        case resizeAnchor
        case ignoreFullScreenWindows
        case showPreview
        case previewPadding
        case previewCornerRadius
        case previewBorderWidth
        case previewBorderColorHex
        case previewBackgroundColorHex
        case previewAnimationSpeed
        case hapticFeedback
        case escapeCancelsRadial
        case rightClickCancelsRadial
        case resizeDiagnostics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        confirmationMode = try container.decodeIfPresent(ConfirmationMode.self, forKey: .confirmationMode) ?? Self.default.confirmationMode
        resizeAnimation = try container.decodeIfPresent(Bool.self, forKey: .resizeAnimation) ?? Self.default.resizeAnimation
        resizeAnimationDuration = try container.decodeIfPresent(Double.self, forKey: .resizeAnimationDuration) ?? Self.default.resizeAnimationDuration
        resizeAnchor = try container.decodeIfPresent(ResizeAnchor.self, forKey: .resizeAnchor) ?? Self.default.resizeAnchor
        ignoreFullScreenWindows = try container.decodeIfPresent(Bool.self, forKey: .ignoreFullScreenWindows) ?? Self.default.ignoreFullScreenWindows
        showPreview = try container.decodeIfPresent(Bool.self, forKey: .showPreview) ?? Self.default.showPreview
        previewPadding = try container.decodeIfPresent(Double.self, forKey: .previewPadding) ?? Self.default.previewPadding
        previewCornerRadius = try container.decodeIfPresent(Double.self, forKey: .previewCornerRadius) ?? Self.default.previewCornerRadius
        previewBorderWidth = try container.decodeIfPresent(Double.self, forKey: .previewBorderWidth) ?? Self.default.previewBorderWidth
        previewBorderColorHex = try container.decodeIfPresent(String.self, forKey: .previewBorderColorHex) ?? Self.default.previewBorderColorHex
        previewBackgroundColorHex = try container.decodeIfPresent(String.self, forKey: .previewBackgroundColorHex) ?? Self.default.previewBackgroundColorHex
        previewAnimationSpeed = try container.decodeIfPresent(Double.self, forKey: .previewAnimationSpeed) ?? Self.default.previewAnimationSpeed
        hapticFeedback = try container.decodeIfPresent(Bool.self, forKey: .hapticFeedback) ?? Self.default.hapticFeedback
        escapeCancelsRadial = try container.decodeIfPresent(Bool.self, forKey: .escapeCancelsRadial) ?? Self.default.escapeCancelsRadial
        rightClickCancelsRadial = try container.decodeIfPresent(Bool.self, forKey: .rightClickCancelsRadial) ?? Self.default.rightClickCancelsRadial
        resizeDiagnostics = try container.decodeIfPresent(Bool.self, forKey: .resizeDiagnostics) ?? Self.default.resizeDiagnostics
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(confirmationMode, forKey: .confirmationMode)
        try container.encode(resizeAnimation, forKey: .resizeAnimation)
        try container.encode(resizeAnimationDuration, forKey: .resizeAnimationDuration)
        try container.encode(resizeAnchor, forKey: .resizeAnchor)
        try container.encode(ignoreFullScreenWindows, forKey: .ignoreFullScreenWindows)
        try container.encode(showPreview, forKey: .showPreview)
        try container.encode(previewPadding, forKey: .previewPadding)
        try container.encode(previewCornerRadius, forKey: .previewCornerRadius)
        try container.encode(previewBorderWidth, forKey: .previewBorderWidth)
        try container.encode(previewBorderColorHex, forKey: .previewBorderColorHex)
        try container.encode(previewBackgroundColorHex, forKey: .previewBackgroundColorHex)
        try container.encode(previewAnimationSpeed, forKey: .previewAnimationSpeed)
        try container.encode(hapticFeedback, forKey: .hapticFeedback)
        try container.encode(escapeCancelsRadial, forKey: .escapeCancelsRadial)
        try container.encode(rightClickCancelsRadial, forKey: .rightClickCancelsRadial)
        try container.encode(resizeDiagnostics, forKey: .resizeDiagnostics)
    }
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
        case .bottomLeft: RadialMenuAction(kind: .portrait405x720)
        case .bottomRight: RadialMenuAction(kind: .threeTwo1200x800)
        case .center: RadialMenuAction(kind: .browser)
        }
    }
}

struct AppRule: Codable, Equatable, Identifiable {
    var id: UUID
    var appName: String
    var bundleIdentifier: String
    var isEnabled: Bool
    var assignments: AssignmentSettings

    init(
        id: UUID = UUID(),
        appName: String,
        bundleIdentifier: String,
        isEnabled: Bool = true,
        assignments: AssignmentSettings = .default
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.isEnabled = isEnabled
        self.assignments = assignments
    }
}

struct AppRuleSettings: Codable, Equatable {
    var isEnabled: Bool
    var rules: [AppRule]

    static let `default` = AppRuleSettings(isEnabled: true, rules: [])

    func matchingRule(for bundleIdentifier: String?) -> AppRule? {
        guard isEnabled, let bundleIdentifier, !bundleIdentifier.isEmpty else { return nil }
        return rules.first { rule in
            rule.isEnabled && rule.bundleIdentifier == bundleIdentifier
        }
    }

    func assignments(for bundleIdentifier: String?, fallback: AssignmentSettings) -> AssignmentSettings {
        matchingRule(for: bundleIdentifier)?.assignments ?? fallback
    }
}

struct AppSettingsSnapshot: Codable, Equatable {
    var wheelStyle: WheelStyleSettings
    var assignments: AssignmentSettings
    var appRules: AppRuleSettings
    var trigger: TriggerSettings
    var behavior: BehaviorSettings
    var general: GeneralSettings

    static let `default` = AppSettingsSnapshot()

    init(
        wheelStyle: WheelStyleSettings = .default,
        assignments: AssignmentSettings = .default,
        appRules: AppRuleSettings = .default,
        trigger: TriggerSettings = .default,
        behavior: BehaviorSettings = .default,
        general: GeneralSettings = .default
    ) {
        self.wheelStyle = wheelStyle
        self.assignments = assignments
        self.appRules = appRules
        self.trigger = trigger
        self.behavior = behavior
        self.general = general
    }
}

extension AppSettingsSnapshot {
    private enum CodingKeys: String, CodingKey {
        case wheelStyle
        case assignments
        case appRules
        case trigger
        case behavior
        case general
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wheelStyle = try container.decodeIfPresent(WheelStyleSettings.self, forKey: .wheelStyle) ?? Self.default.wheelStyle
        assignments = try container.decodeIfPresent(AssignmentSettings.self, forKey: .assignments) ?? Self.default.assignments
        appRules = try container.decodeIfPresent(AppRuleSettings.self, forKey: .appRules) ?? Self.default.appRules
        trigger = try container.decodeIfPresent(TriggerSettings.self, forKey: .trigger) ?? Self.default.trigger
        behavior = try container.decodeIfPresent(BehaviorSettings.self, forKey: .behavior) ?? Self.default.behavior
        general = try container.decodeIfPresent(GeneralSettings.self, forKey: .general) ?? Self.default.general
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(wheelStyle, forKey: .wheelStyle)
        try container.encode(assignments, forKey: .assignments)
        try container.encode(appRules, forKey: .appRules)
        try container.encode(trigger, forKey: .trigger)
        try container.encode(behavior, forKey: .behavior)
        try container.encode(general, forKey: .general)
    }
}
