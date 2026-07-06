import AppKit
import Combine

@MainActor
final class AppIconProvider: ObservableObject {
    static let shared = AppIconProvider()

    @Published private(set) var currentIcon: NSImage

    private var appearanceObserver: NSKeyValueObservation?

    private init() {
        currentIcon = Self.defaultIcon()
    }

    func start() {
        updateIcon()

        guard appearanceObserver == nil else { return }

        appearanceObserver = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { _, _ in
            Task { @MainActor in
                Self.shared.updateIcon()
            }
        }
    }

    func updateIcon() {
        let application = NSApplication.shared
        let icon = Self.icon(for: application.effectiveAppearance, fallback: application.applicationIconImage)
        currentIcon = icon
        application.applicationIconImage = icon
    }

    private static func icon(for appearance: NSAppearance, fallback: NSImage?) -> NSImage {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let assetName = isDark ? "AppIconDark" : "AppIconLight"
        return NSImage(named: assetName) ?? fallback ?? defaultIcon()
    }

    private static func defaultIcon() -> NSImage {
        NSImage(named: "AppIconLight") ?? NSImage(named: "AppIconDark") ?? NSImage()
    }
}
