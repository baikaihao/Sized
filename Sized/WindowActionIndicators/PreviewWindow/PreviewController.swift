import AppKit
import SwiftUI

@MainActor
final class PreviewController {
    private var panel: ActivePanel?
    private var isVisible = false
    private var settings: SettingsStore { .shared }

    func show(frame: CGRect, style: WindowActionPreviewStyle = .standard) {
        guard settings.behavior.showPreview || style == .danger else { return }
        let inset = style == .danger ? 0 : CGFloat(settings.behavior.previewPadding)
        let displayFrame = frame.insetBy(dx: inset, dy: inset)
        let speed = settings.behavior.previewAnimationSpeed

        let wasVisible = isVisible
        let panel = panel ?? makePanel()
        let rootView = PreviewView(settings: settings.behavior, style: style)

        if !wasVisible {
            panel.setFrame(displayFrame, display: false)
            panel.contentView = NSHostingView(rootView: rootView)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            isVisible = true
            self.panel = panel

            NSAnimationContext.runAnimationGroup { context in
                context.duration = speed * 0.75
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            if let hostingView = panel.contentView as? NSHostingView<PreviewView> {
                hostingView.rootView = rootView
            } else {
                panel.contentView = NSHostingView(rootView: rootView)
            }

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
        let speed = settings.behavior.previewAnimationSpeed

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = speed * 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let controller = self else { return }
            Task { @MainActor [controller, panel] in
                guard !controller.isVisible else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1
                if controller.panel === panel {
                    controller.panel = nil
                }
            }
        })
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
