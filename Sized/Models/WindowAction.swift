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
        case .custom: "自定义尺寸".localized
        case .utility: "辅助操作".localized
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
    case ultrawide840x360
    case ultrawide980x420
    case ultrawide1120x480
    case ultrawide1280x540
    case ultrawide1680x720
    case ultrawide2560x1080
    case ultrawide3440x1440
    case sixteenTen640x400
    case sixteenTen800x500
    case sixteenTen1024x640
    case sixteenTen1680x1050
    case sixteenTen1920x1200
    case sixteenNine640x360
    case sixteenNine854x480
    case sixteenNine1024x576
    case sixteenNine1600x900
    case portrait180x320
    case portrait270x480
    case portrait320x568
    case portrait360x640
    case portrait405x720
    case portrait450x800
    case portrait540x960
    case fourThree320x240
    case fourThree480x360
    case fourThree600x450
    case fourThree1280x960
    case threeTwo450x300
    case threeTwo600x400
    case threeTwo750x500
    case threeTwo900x600
    case threeTwo1200x800
    case threeTwo1440x960
    case threeTwo1800x1200
    case square240x240
    case square320x320
    case square360x360
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
        case .tall: "竖向 900 x 1200".localized
        case .laptop: "1366 x 768"
        case .desktop: "1600 x 1000"
        case .presentation: "1920 x 1080"
        case .browser: "1280 x 720"
        case .mobilePortrait: "手机竖屏 390 x 844".localized
        case .mobileLandscape: "手机横屏 844 x 390".localized
        case .tabletPortrait: "平板竖屏 768 x 1024".localized
        case .tabletLandscape: "平板横屏 1024 x 768".localized
        case .square: "900 x 900"
        case .ultrawide840x360: "840 x 360"
        case .ultrawide980x420: "980 x 420"
        case .ultrawide1120x480: "1120 x 480"
        case .ultrawide1280x540: "1280 x 540"
        case .ultrawide1680x720: "1680 x 720"
        case .ultrawide2560x1080: "2560 x 1080"
        case .ultrawide3440x1440: "3440 x 1440"
        case .sixteenTen640x400: "640 x 400"
        case .sixteenTen800x500: "800 x 500"
        case .sixteenTen1024x640: "1024 x 640"
        case .sixteenTen1680x1050: "1680 x 1050"
        case .sixteenTen1920x1200: "1920 x 1200"
        case .sixteenNine640x360: "640 x 360"
        case .sixteenNine854x480: "854 x 480"
        case .sixteenNine1024x576: "1024 x 576"
        case .sixteenNine1600x900: "1600 x 900"
        case .portrait180x320: "180 x 320"
        case .portrait270x480: "270 x 480"
        case .portrait320x568: "320 x 568"
        case .portrait360x640: "360 x 640"
        case .portrait405x720: "405 x 720"
        case .portrait450x800: "450 x 800"
        case .portrait540x960: "540 x 960"
        case .fourThree320x240: "320 x 240"
        case .fourThree480x360: "480 x 360"
        case .fourThree600x450: "600 x 450"
        case .fourThree1280x960: "1280 x 960"
        case .threeTwo450x300: "450 x 300"
        case .threeTwo600x400: "600 x 400"
        case .threeTwo750x500: "750 x 500"
        case .threeTwo900x600: "900 x 600"
        case .threeTwo1200x800: "1200 x 800"
        case .threeTwo1440x960: "1440 x 960"
        case .threeTwo1800x1200: "1800 x 1200"
        case .square240x240: "240 x 240"
        case .square320x320: "320 x 320"
        case .square360x360: "360 x 360"
        case .square480x480: "480 x 480"
        case .square720x720: "720 x 720"
        case .square1200x1200: "1200 x 1200"
        case .custom: "自定义尺寸".localized
        case .restoreInitial: "恢复初始尺寸".localized
        case .undo: "撤销上一次尺寸".localized
        case .none: "无操作".localized
        }
    }

    var category: SizePresetCategory {
        switch self {
        case .ultrawide840x360, .ultrawide980x420, .ultrawide1120x480, .ultrawide1280x540, .ultrawide1680x720, .ultrawide2560x1080, .ultrawide3440x1440:
            .ultrawide21x9
        case .large, .wide, .desktop, .sixteenTen640x400, .sixteenTen800x500, .sixteenTen1024x640, .sixteenTen1680x1050, .sixteenTen1920x1200:
            .widescreen16x10
        case .browser, .laptop, .presentation, .sixteenNine640x360, .sixteenNine854x480, .sixteenNine1024x576, .sixteenNine1600x900, .mobileLandscape:
            .widescreen16x9
        case .portrait180x320, .portrait270x480, .portrait320x568, .portrait360x640, .portrait405x720, .portrait450x800, .portrait540x960, .mobilePortrait, .tall, .tabletPortrait:
            .portrait9x16
        case .small, .compact, .medium, .fourThree320x240, .fourThree480x360, .fourThree600x450, .fourThree1280x960, .tabletLandscape:
            .classic4x3
        case .threeTwo450x300, .threeTwo600x400, .threeTwo750x500, .threeTwo900x600, .threeTwo1200x800, .threeTwo1440x960, .threeTwo1800x1200:
            .photo3x2
        case .square, .square240x240, .square320x320, .square360x360, .square480x480, .square720x720, .square1200x1200:
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
        case .ultrawide840x360: CGSizePreset(width: 840, height: 360)
        case .ultrawide980x420: CGSizePreset(width: 980, height: 420)
        case .ultrawide1120x480: CGSizePreset(width: 1120, height: 480)
        case .ultrawide1280x540: CGSizePreset(width: 1280, height: 540)
        case .ultrawide1680x720: CGSizePreset(width: 1680, height: 720)
        case .ultrawide2560x1080: CGSizePreset(width: 2560, height: 1080)
        case .ultrawide3440x1440: CGSizePreset(width: 3440, height: 1440)
        case .sixteenTen640x400: CGSizePreset(width: 640, height: 400)
        case .sixteenTen800x500: CGSizePreset(width: 800, height: 500)
        case .sixteenTen1024x640: CGSizePreset(width: 1024, height: 640)
        case .sixteenTen1680x1050: CGSizePreset(width: 1680, height: 1050)
        case .sixteenTen1920x1200: CGSizePreset(width: 1920, height: 1200)
        case .sixteenNine640x360: CGSizePreset(width: 640, height: 360)
        case .sixteenNine854x480: CGSizePreset(width: 854, height: 480)
        case .sixteenNine1024x576: CGSizePreset(width: 1024, height: 576)
        case .sixteenNine1600x900: CGSizePreset(width: 1600, height: 900)
        case .portrait180x320: CGSizePreset(width: 180, height: 320)
        case .portrait270x480: CGSizePreset(width: 270, height: 480)
        case .portrait320x568: CGSizePreset(width: 320, height: 568)
        case .portrait360x640: CGSizePreset(width: 360, height: 640)
        case .portrait405x720: CGSizePreset(width: 405, height: 720)
        case .portrait450x800: CGSizePreset(width: 450, height: 800)
        case .portrait540x960: CGSizePreset(width: 540, height: 960)
        case .fourThree320x240: CGSizePreset(width: 320, height: 240)
        case .fourThree480x360: CGSizePreset(width: 480, height: 360)
        case .fourThree600x450: CGSizePreset(width: 600, height: 450)
        case .fourThree1280x960: CGSizePreset(width: 1280, height: 960)
        case .threeTwo450x300: CGSizePreset(width: 450, height: 300)
        case .threeTwo600x400: CGSizePreset(width: 600, height: 400)
        case .threeTwo750x500: CGSizePreset(width: 750, height: 500)
        case .threeTwo900x600: CGSizePreset(width: 900, height: 600)
        case .threeTwo1200x800: CGSizePreset(width: 1200, height: 800)
        case .threeTwo1440x960: CGSizePreset(width: 1440, height: 960)
        case .threeTwo1800x1200: CGSizePreset(width: 1800, height: 1200)
        case .square240x240: CGSizePreset(width: 240, height: 240)
        case .square320x320: CGSizePreset(width: 320, height: 320)
        case .square360x360: CGSizePreset(width: 360, height: 360)
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
        case .wide, .browser, .presentation, .ultrawide840x360, .ultrawide980x420, .ultrawide1120x480, .ultrawide1280x540, .ultrawide1680x720, .ultrawide2560x1080, .ultrawide3440x1440, .sixteenTen640x400, .sixteenTen800x500, .sixteenTen1024x640, .sixteenTen1680x1050, .sixteenTen1920x1200, .sixteenNine640x360, .sixteenNine854x480, .sixteenNine1024x576, .sixteenNine1600x900: "rectangle.wide"
        case .tall, .portrait180x320, .portrait270x480, .portrait320x568, .portrait360x640, .portrait405x720, .portrait450x800, .portrait540x960: "rectangle.portrait"
        case .laptop: "laptopcomputer"
        case .desktop: "desktopcomputer"
        case .mobilePortrait: "iphone"
        case .mobileLandscape: "iphone.landscape"
        case .tabletPortrait: "ipad"
        case .tabletLandscape: "ipad.landscape"
        case .fourThree320x240, .fourThree480x360, .fourThree600x450, .fourThree1280x960, .threeTwo450x300, .threeTwo600x400, .threeTwo750x500, .threeTwo900x600, .threeTwo1200x800, .threeTwo1440x960, .threeTwo1800x1200: "rectangle"
        case .square, .square240x240, .square320x320, .square360x360, .square480x480, .square720x720, .square1200x1200: "square"
        case .custom: "slider.horizontal.3"
        case .restoreInitial: "arrow.uturn.backward"
        case .undo: "arrow.counterclockwise"
        case .none: "slash.circle"
        }
    }

    static var selectable: [SizePresetKind] {
        [
            .ultrawide840x360,
            .ultrawide980x420,
            .ultrawide1120x480,
            .ultrawide1280x540,
            .ultrawide1680x720,
            .ultrawide2560x1080,
            .ultrawide3440x1440,
            .sixteenTen640x400,
            .sixteenTen800x500,
            .sixteenTen1024x640,
            .large,
            .wide,
            .desktop,
            .sixteenTen1680x1050,
            .sixteenTen1920x1200,
            .sixteenNine640x360,
            .sixteenNine854x480,
            .sixteenNine1024x576,
            .browser,
            .laptop,
            .sixteenNine1600x900,
            .presentation,
            .portrait180x320,
            .portrait270x480,
            .portrait320x568,
            .portrait360x640,
            .portrait405x720,
            .portrait450x800,
            .portrait540x960,
            .fourThree320x240,
            .fourThree480x360,
            .fourThree600x450,
            .small,
            .compact,
            .medium,
            .fourThree1280x960,
            .threeTwo450x300,
            .threeTwo600x400,
            .threeTwo750x500,
            .threeTwo900x600,
            .threeTwo1200x800,
            .threeTwo1440x960,
            .threeTwo1800x1200,
            .square240x240,
            .square320x320,
            .square360x360,
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
