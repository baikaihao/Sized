import AppKit
import SwiftUI

@MainActor
final class PreviewController {
    private var panel: ActivePanel?
    private var settings: SettingsStore { .shared }

    func show(frame: CGRect) {
        guard settings.behavior.showPreview else { return }
        let inset = CGFloat(settings.behavior.previewPadding)
        let displayFrame = frame.insetBy(dx: inset, dy: inset)
        let panel = panel ?? makePanel()
        panel.setFrame(displayFrame, display: true)
        panel.contentView = NSHostingView(rootView: PreviewView(settings: settings.behavior))
        self.panel = panel
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func makePanel() -> ActivePanel {
        let panel = ActivePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .screenSaver
        return panel
    }
}
