import AppKit
import SwiftUI

@MainActor
final class PreviewController {
    private var panel: ActivePanel?
    private var isVisible = false
    private var hideGeneration = 0
    private var settings: SettingsStore { .shared }

    func show(frame: CGRect, style: WindowActionPreviewStyle = .standard) {
        guard settings.behavior.showPreview else {
            hide()
            return
        }
        hideGeneration += 1
        let inset = style == .danger ? 0 : CGFloat(settings.behavior.previewPadding)
        let displayFrame = frame.insetBy(dx: inset, dy: inset)
        let speed = settings.behavior.previewAnimationSpeed

        let wasVisible = isVisible
        let panel = panel ?? makePanel()
        let rootView = PreviewView(settings: settings.behavior, style: style)
        if let hostingView = panel.contentView as? NSHostingView<PreviewView> {
            hostingView.rootView = rootView
        } else {
            panel.contentView = NSHostingView(rootView: rootView)
        }
        self.panel = panel

        if !wasVisible {
            panel.setFrame(displayFrame, display: false)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            isVisible = true

            NSAnimationContext.runAnimationGroup { context in
                context.duration = speed * 0.75
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = speed
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(displayFrame, display: true)
            }
        }
    }

    func hide() {
        guard let panel, isVisible else { return }
        isVisible = false
        hideGeneration += 1
        let generation = hideGeneration
        let speed = settings.behavior.previewAnimationSpeed

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = speed * 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let controller = self else { return }
            Task { @MainActor [controller, panel] in
                guard controller.hideGeneration == generation else { return }
                guard !controller.isVisible else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        })
    }

    func hideImmediately() {
        hideGeneration += 1
        isVisible = false
        panel?.orderOut(nil)
        panel?.alphaValue = 1
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
