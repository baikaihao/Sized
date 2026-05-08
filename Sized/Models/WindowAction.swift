import Foundation

enum SizePresetCategory: String, CaseIterable, Codable, Identifiable {
    case common
    case device
    case custom
    case utility

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .common: "常用尺寸"
        case .device: "设备参考"
        case .custom: "自定义尺寸"
        case .utility: "辅助操作"
        }
    }
}

enum SizePresetKind: String, CaseIterable, Codable, Identifiable {
    case small
    case compact
    case medium
    case large
    case wide
    case tall
    case laptop
    case desktop
    case presentation
    case browser
    case mobilePortrait
    case mobileLandscape
    case tabletPortrait
    case tabletLandscape
    case square
    case custom
    case restoreInitial
    case undo
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: "小窗口 640 x 480"
        case .compact: "紧凑 800 x 600"
        case .medium: "中等 1024 x 768"
        case .large: "大窗口 1280 x 800"
        case .wide: "宽屏 1440 x 900"
        case .tall: "竖向 900 x 1200"
        case .laptop: "笔记本 1366 x 768"
        case .desktop: "桌面 1600 x 1000"
        case .presentation: "演示 1920 x 1080"
        case .browser: "浏览器 1280 x 720"
        case .mobilePortrait: "手机竖屏 390 x 844"
        case .mobileLandscape: "手机横屏 844 x 390"
        case .tabletPortrait: "平板竖屏 768 x 1024"
        case .tabletLandscape: "平板横屏 1024 x 768"
        case .square: "正方形 900 x 900"
        case .custom: "自定义尺寸"
        case .restoreInitial: "恢复初始尺寸"
        case .undo: "撤销上一次尺寸"
        case .none: "无操作"
        }
    }

    var category: SizePresetCategory {
        switch self {
        case .small, .compact, .medium, .large, .wide, .tall, .square:
            .common
        case .laptop, .desktop, .presentation, .browser, .mobilePortrait, .mobileLandscape, .tabletPortrait, .tabletLandscape:
            .device
        case .custom:
            .custom
        case .restoreInitial, .undo, .none:
            .utility
        }
    }

    var fixedSize: CGSizePreset? {
        switch self {
        case .small: CGSizePreset(width: 640, height: 480)
        case .compact: CGSizePreset(width: 800, height: 600)
        case .medium: CGSizePreset(width: 1024, height: 768)
        case .large: CGSizePreset(width: 1280, height: 800)
        case .wide: CGSizePreset(width: 1440, height: 900)
        case .tall: CGSizePreset(width: 900, height: 1200)
        case .laptop: CGSizePreset(width: 1366, height: 768)
        case .desktop: CGSizePreset(width: 1600, height: 1000)
        case .presentation: CGSizePreset(width: 1920, height: 1080)
        case .browser: CGSizePreset(width: 1280, height: 720)
        case .mobilePortrait: CGSizePreset(width: 390, height: 844)
        case .mobileLandscape: CGSizePreset(width: 844, height: 390)
        case .tabletPortrait: CGSizePreset(width: 768, height: 1024)
        case .tabletLandscape: CGSizePreset(width: 1024, height: 768)
        case .square: CGSizePreset(width: 900, height: 900)
        case .custom, .restoreInitial, .undo, .none:
            nil
        }
    }

    var systemImage: String {
        switch self {
        case .small, .compact: "rectangle"
        case .medium, .large: "macwindow"
        case .wide, .browser, .presentation: "rectangle.wide"
        case .tall: "rectangle.portrait"
        case .laptop: "laptopcomputer"
        case .desktop: "desktopcomputer"
        case .mobilePortrait: "iphone"
        case .mobileLandscape: "iphone.landscape"
        case .tabletPortrait: "ipad"
        case .tabletLandscape: "ipad.landscape"
        case .square: "square"
        case .custom: "slider.horizontal.3"
        case .restoreInitial: "arrow.uturn.backward"
        case .undo: "arrow.counterclockwise"
        case .none: "slash.circle"
        }
    }

    static var selectable: [SizePresetKind] {
        allCases
    }
}

struct CGSizePreset: Codable, Equatable {
    var width: Double
    var height: Double
}

struct CustomWindowSize: Codable, Equatable {
    var width: Double
    var height: Double

    static let `default` = CustomWindowSize(width: 1280, height: 800)
}

struct RadialMenuAction: Codable, Equatable, Identifiable {
    var id: UUID
    var kind: SizePresetKind
    var customLabel: String
    var customSize: CustomWindowSize

    init(id: UUID = UUID(), kind: SizePresetKind, customLabel: String = "", customSize: CustomWindowSize = .default) {
        self.id = id
        self.kind = kind
        self.customLabel = customLabel
        self.customSize = customSize
    }

    var displayName: String {
        customLabel.isEmpty ? kind.displayName : customLabel
    }

    var sizeDisplayName: String {
        if kind == .custom {
            return "\(Int(customSize.width)) x \(Int(customSize.height))"
        }
        if let size = kind.fixedSize {
            return "\(Int(size.width)) x \(Int(size.height))"
        }
        return kind.displayName
    }

    var systemImage: String { kind.systemImage }
}
