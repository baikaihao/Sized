import AppKit

@MainActor
final class StatusItemController {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private var openSized: (() -> Void)?

    private init() {}

    func configure(openSized: @escaping () -> Void) {
        self.openSized = openSized
    }

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
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            image.size = NSSize(width: 15, height: 15)
            item.button?.image = image
            item.button?.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        menu.autoenablesItems = false

        let openItem = NSMenuItem(
            title: "打开 Sized".localized,
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        let quitItem = NSMenuItem(
            title: "退出 Sized".localized,
            action: #selector(quitApp),
            keyEquivalent: "q"
        )

        [openItem, quitItem].forEach { $0.target = self }
        menu.items = [openItem, quitItem]

        item.menu = menu
        statusItem = item
    }

    private func hide() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    @objc private func openSettings() {
        openSized?()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
