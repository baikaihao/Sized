import AppKit

@MainActor
final class WindowActionIndicatorService {
    let radialMenu = RadialMenuController()
    let preview = PreviewController()

    func showRadialMenu(at point: CGPoint, selectedSlot: RadialMenuSlot?, action: RadialMenuAction?, hasTargetWindow: Bool) {
        radialMenu.show(at: point, selectedSlot: selectedSlot, action: action, hasTargetWindow: hasTargetWindow)
    }

    func updateRadialMenu(selectedSlot: RadialMenuSlot?, action: RadialMenuAction?, hasTargetWindow: Bool) {
        radialMenu.update(selectedSlot: selectedSlot, action: action, hasTargetWindow: hasTargetWindow)
    }

    func hideAll() {
        radialMenu.hide()
        preview.hide()
    }
}
