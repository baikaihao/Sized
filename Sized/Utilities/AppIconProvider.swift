import AppKit
import Combine

@MainActor
final class AppIconProvider: ObservableObject {
    static let shared = AppIconProvider()

    @Published private(set) var currentIcon: NSImage

    private var appearanceObserver: NSKeyValueObservation?

    private init() {
        currentIcon = Self.icon(for: NSApp.effectiveAppearance)
    }

    func start() {
        updateIcon()

        appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.new]) { _, _ in
            Task { @MainActor in
                Self.shared.updateIcon()
            }
        }
    }

    func updateIcon() {
        let icon = Self.icon(for: NSApp.effectiveAppearance)
        currentIcon = icon
        NSApp.applicationIconImage = icon
    }

    private static func icon(for appearance: NSAppearance) -> NSImage {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let assetName = isDark ? "AppIconDark" : "AppIconLight"
        return NSImage(named: assetName) ?? NSApp.applicationIconImage ?? NSImage()
    }
}
