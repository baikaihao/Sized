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
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "circle.grid.cross", accessibilityDescription: "Sized")
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开 Sized", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "请求辅助功能权限", action: #selector(requestAccessibility), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
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

    @objc private func requestAccessibility() {
        AccessibilityManager.shared.requestAccess()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
