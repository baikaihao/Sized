import AppKit

@MainActor
final class StatusItemController {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?

    private init() {}

    func applyVisibility(_ visible: Bool) {
        if visible {
            show()
        } else {
            hide()
        }
    }

    private func show() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: 14)
        let icon = NSImage(named: "MenuBarIcon")
        icon?.isTemplate = true
        icon?.size = NSSize(width: 14, height: 14)
        item.button?.image = icon
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开 Sized".localized, action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "退出 Sized".localized, action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func hide() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    @objc private func openSettings() {
        SizedManager.shared.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
