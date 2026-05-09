import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private let settings = SettingsStore.shared

    private override init() {}

    func show() {
        let window = window ?? makeWindow()

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makeWindow() -> NSWindow {
        let contentView = SettingsView()
            .environmentObject(settings)

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 920, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Sized"
        window.identifier = NSUserInterfaceItemIdentifier("Sized.SettingsWindow")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 920, height: 660)
        window.tabbingMode = .disallowed
        window.contentView = NSHostingView(rootView: contentView)
        window.delegate = self
        window.center()

        self.window = window
        return window
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
