import AppKit
import SwiftUI

@MainActor
final class RadialMenuController {
    private var panel: ActivePanel?
    private var viewModel = RadialMenuViewModel()
    private var settings: SettingsStore { .shared }

    var isShown: Bool {
        panel?.isVisible == true
    }

    func show(at origin: CGPoint, selectedSlot: RadialMenuSlot?, action: RadialMenuAction?, hasTargetWindow: Bool) {
        let style = settings.wheelStyle
        let size = CGFloat(style.size + 80)
        let screen = ScreenUtility.screen(containing: origin)
        let center = style.lockToScreenCenter ? ScreenUtility.centerPoint(in: screen) : origin
        let frame = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)

        viewModel.update(selectedSlot: selectedSlot, action: action, hasTargetWindow: hasTargetWindow)
        viewModel.setIsShown(false)

        let panel = panel ?? makePanel(size: size)
        panel.setFrame(frame, display: true)
        panel.contentView = NSHostingView(
            rootView: RadialMenuPanelContent(viewModel: viewModel)
                .environmentObject(settings)
        )

        self.panel = panel
        panel.orderFrontRegardless()

        DispatchQueue.main.async {
            self.viewModel.setIsShown(true)
        }
    }

    func update(selectedSlot: RadialMenuSlot?, action: RadialMenuAction?, hasTargetWindow: Bool) {
        viewModel.update(selectedSlot: selectedSlot, action: action, hasTargetWindow: hasTargetWindow)
    }

    func hide() {
        guard let panel else { return }
        viewModel.setIsShown(false)
        let delay = settings.wheelStyle.appearanceAnimation ? 0.15 : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            panel.orderOut(nil)
            if self.panel === panel {
                self.panel = nil
            }
        }
    }

    private func makePanel(size: CGFloat) -> ActivePanel {
        let panel = ActivePanel(
            contentRect: CGRect(x: 0, y: 0, width: size, height: size),
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

private struct RadialMenuPanelContent: View {
    @ObservedObject var viewModel: RadialMenuViewModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        RadialMenuView(
            selectedSlot: viewModel.selectedSlot,
            action: viewModel.action,
            style: settings.wheelStyle,
            hasTargetWindow: viewModel.hasTargetWindow,
            isShown: viewModel.isShown
        )
        .environmentObject(settings)
    }
}
