import Foundation

enum SizePresetCategory: String, CaseIterable, Codable, Identifiable {
    case ultrawide21x9
    case widescreen16x10
    case widescreen16x9
    case portrait9x16
    case classic4x3
    case photo3x2
    case square1x1
    case custom
    case utility

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ultrawide21x9: "21:9"
        case .widescreen16x10: "16:10"
        case .widescreen16x9: "16:9"
        case .portrait9x16: "9:16"
        case .classic4x3: "4:3"
        case .photo3x2: "3:2"
        case .square1x1: "1:1"
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
    case ultrawide1280x540
    case ultrawide1680x720
    case ultrawide2560x1080
    case ultrawide3440x1440
    case sixteenTen1680x1050
    case sixteenTen1920x1200
    case sixteenNine1600x900
    case portrait360x640
    case portrait405x720
    case portrait450x800
    case portrait540x960
    case fourThree1280x960
    case threeTwo900x600
    case threeTwo1200x800
    case threeTwo1440x960
    case threeTwo1800x1200
    case square480x480
    case square720x720
    case square1200x1200
    case custom
    case restoreInitial
    case undo
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: "640 x 480"
        case .compact: "800 x 600"
        case .medium: "1024 x 768"
        case .large: "1280 x 800"
        case .wide: "1440 x 900"
        case .tall: "竖向 900 x 1200"
        case .laptop: "1366 x 768"
        case .desktop: "1600 x 1000"
        case .presentation: "1920 x 1080"
        case .browser: "1280 x 720"
        case .mobilePortrait: "手机竖屏 390 x 844"
        case .mobileLandscape: "手机横屏 844 x 390"
        case .tabletPortrait: "平板竖屏 768 x 1024"
        case .tabletLandscape: "平板横屏 1024 x 768"
        case .square: "900 x 900"
        case .ultrawide1280x540: "1280 x 540"
        case .ultrawide1680x720: "1680 x 720"
        case .ultrawide2560x1080: "2560 x 1080"
        case .ultrawide3440x1440: "3440 x 1440"
        case .sixteenTen1680x1050: "1680 x 1050"
        case .sixteenTen1920x1200: "1920 x 1200"
        case .sixteenNine1600x900: "1600 x 900"
        case .portrait360x640: "360 x 640"
        case .portrait405x720: "405 x 720"
        case .portrait450x800: "450 x 800"
        case .portrait540x960: "540 x 960"
        case .fourThree1280x960: "1280 x 960"
        case .threeTwo900x600: "900 x 600"
        case .threeTwo1200x800: "1200 x 800"
        case .threeTwo1440x960: "1440 x 960"
        case .threeTwo1800x1200: "1800 x 1200"
        case .square480x480: "480 x 480"
        case .square720x720: "720 x 720"
        case .square1200x1200: "1200 x 1200"
        case .custom: "自定义尺寸"
        case .restoreInitial: "恢复初始尺寸"
        case .undo: "撤销上一次尺寸"
        case .none: "无操作"
        }
    }

    var category: SizePresetCategory {
        switch self {
        case .ultrawide1280x540, .ultrawide1680x720, .ultrawide2560x1080, .ultrawide3440x1440:
            .ultrawide21x9
        case .large, .wide, .desktop, .sixteenTen1680x1050, .sixteenTen1920x1200:
            .widescreen16x10
        case .browser, .laptop, .presentation, .sixteenNine1600x900, .mobileLandscape:
            .widescreen16x9
        case .portrait360x640, .portrait405x720, .portrait450x800, .portrait540x960, .mobilePortrait, .tall, .tabletPortrait:
            .portrait9x16
        case .small, .compact, .medium, .fourThree1280x960, .tabletLandscape:
            .classic4x3
        case .threeTwo900x600, .threeTwo1200x800, .threeTwo1440x960, .threeTwo1800x1200:
            .photo3x2
        case .square, .square480x480, .square720x720, .square1200x1200:
            .square1x1
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
        case .ultrawide1280x540: CGSizePreset(width: 1280, height: 540)
        case .ultrawide1680x720: CGSizePreset(width: 1680, height: 720)
        case .ultrawide2560x1080: CGSizePreset(width: 2560, height: 1080)
        case .ultrawide3440x1440: CGSizePreset(width: 3440, height: 1440)
        case .sixteenTen1680x1050: CGSizePreset(width: 1680, height: 1050)
        case .sixteenTen1920x1200: CGSizePreset(width: 1920, height: 1200)
        case .sixteenNine1600x900: CGSizePreset(width: 1600, height: 900)
        case .portrait360x640: CGSizePreset(width: 360, height: 640)
        case .portrait405x720: CGSizePreset(width: 405, height: 720)
        case .portrait450x800: CGSizePreset(width: 450, height: 800)
        case .portrait540x960: CGSizePreset(width: 540, height: 960)
        case .fourThree1280x960: CGSizePreset(width: 1280, height: 960)
        case .threeTwo900x600: CGSizePreset(width: 900, height: 600)
        case .threeTwo1200x800: CGSizePreset(width: 1200, height: 800)
        case .threeTwo1440x960: CGSizePreset(width: 1440, height: 960)
        case .threeTwo1800x1200: CGSizePreset(width: 1800, height: 1200)
        case .square480x480: CGSizePreset(width: 480, height: 480)
        case .square720x720: CGSizePreset(width: 720, height: 720)
        case .square1200x1200: CGSizePreset(width: 1200, height: 1200)
        case .custom, .restoreInitial, .undo, .none:
            nil
        }
    }

    var systemImage: String {
        switch self {
        case .small, .compact: "rectangle"
        case .medium, .large: "macwindow"
        case .wide, .browser, .presentation, .ultrawide1280x540, .ultrawide1680x720, .ultrawide2560x1080, .ultrawide3440x1440, .sixteenTen1680x1050, .sixteenTen1920x1200, .sixteenNine1600x900: "rectangle.wide"
        case .tall, .portrait360x640, .portrait405x720, .portrait450x800, .portrait540x960: "rectangle.portrait"
        case .laptop: "laptopcomputer"
        case .desktop: "desktopcomputer"
        case .mobilePortrait: "iphone"
        case .mobileLandscape: "iphone.landscape"
        case .tabletPortrait: "ipad"
        case .tabletLandscape: "ipad.landscape"
        case .fourThree1280x960, .threeTwo900x600, .threeTwo1200x800, .threeTwo1440x960, .threeTwo1800x1200: "rectangle"
        case .square, .square480x480, .square720x720, .square1200x1200: "square"
        case .custom: "slider.horizontal.3"
        case .restoreInitial: "arrow.uturn.backward"
        case .undo: "arrow.counterclockwise"
        case .none: "slash.circle"
        }
    }

    static var selectable: [SizePresetKind] {
        [
            .ultrawide1280x540,
            .ultrawide1680x720,
            .ultrawide2560x1080,
            .ultrawide3440x1440,
            .large,
            .wide,
            .desktop,
            .sixteenTen1680x1050,
            .sixteenTen1920x1200,
            .browser,
            .laptop,
            .sixteenNine1600x900,
            .presentation,
            .portrait360x640,
            .portrait405x720,
            .portrait450x800,
            .portrait540x960,
            .small,
            .compact,
            .medium,
            .fourThree1280x960,
            .threeTwo900x600,
            .threeTwo1200x800,
            .threeTwo1440x960,
            .threeTwo1800x1200,
            .square480x480,
            .square720x720,
            .square,
            .square1200x1200,
            .custom,
            .restoreInitial,
            .undo,
            .none
        ]
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
