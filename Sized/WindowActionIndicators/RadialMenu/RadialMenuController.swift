import AppKit
import SwiftUI

@MainActor
final class RadialMenuController {
    private var panel: ActivePanel?
    private var viewModel = RadialMenuViewModel()
    private var hideWorkItem: DispatchWorkItem?
    private var presentationGeneration = 0
    private var settings: SettingsStore { .shared }

    var isShown: Bool {
        panel?.isVisible == true
    }

    func show(at origin: CGPoint, selectedSlot: RadialMenuSlot?, action: RadialMenuAction?, assignments: AssignmentSettings, hasTargetWindow: Bool) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        presentationGeneration &+= 1
        let generation = presentationGeneration

        let style = settings.wheelStyle
        let size = RadialMenuView.canvasSize(for: style)
        let screen = ScreenUtility.screen(containing: origin)
        let center = style.lockToScreenCenter ? ScreenUtility.centerPoint(in: screen) : origin
        let frame = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)

        viewModel.update(selectedSlot: selectedSlot, action: action, assignments: assignments, hasTargetWindow: hasTargetWindow)
        viewModel.setIsShown(false)

        let panel = panel ?? makePanel(size: size)
        panel.setFrame(frame, display: true)

        self.panel = panel
        panel.orderFrontRegardless()

        DispatchQueue.main.async { [weak self, panel] in
            guard let self,
                  self.presentationGeneration == generation,
                  self.panel === panel,
                  panel.isVisible
            else { return }
            self.viewModel.setIsShown(true)
        }
    }

    func update(selectedSlot: RadialMenuSlot?, action: RadialMenuAction?, assignments: AssignmentSettings, hasTargetWindow: Bool) {
        viewModel.update(selectedSlot: selectedSlot, action: action, assignments: assignments, hasTargetWindow: hasTargetWindow)
    }

    func hide() {
        guard let panel else { return }
        hideWorkItem?.cancel()
        presentationGeneration &+= 1
        let generation = presentationGeneration
        viewModel.setIsShown(false)
        let delay = settings.wheelStyle.appearanceAnimation ? 0.15 : 0

        let workItem = DispatchWorkItem { [weak self, panel] in
            guard let self,
                  self.presentationGeneration == generation,
                  self.panel === panel
            else { return }
            panel.orderOut(nil)
            self.hideWorkItem = nil
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func hideImmediately() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        presentationGeneration &+= 1
        viewModel.setIsShown(false)
        panel?.orderOut(nil)
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
        panel.contentView = NSHostingView(
            rootView: RadialMenuPanelContent(viewModel: viewModel)
                .environmentObject(settings)
        )
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
            assignments: viewModel.assignments,
            style: settings.wheelStyle,
            hasTargetWindow: viewModel.hasTargetWindow,
            isShown: viewModel.isShown
        )
        .environmentObject(settings)
    }
}
