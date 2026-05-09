import AppKit

@MainActor
final class WindowActionIndicatorService {
    let radialMenu = RadialMenuController()
    let preview = PreviewController()

    func showRadialMenu(at point: CGPoint, selectedSlot: RadialMenuSlot?, action: RadialMenuAction?, assignments: AssignmentSettings, hasTargetWindow: Bool) {
        radialMenu.show(at: point, selectedSlot: selectedSlot, action: action, assignments: assignments, hasTargetWindow: hasTargetWindow)
    }

    func updateRadialMenu(selectedSlot: RadialMenuSlot?, action: RadialMenuAction?, assignments: AssignmentSettings, hasTargetWindow: Bool) {
        radialMenu.update(selectedSlot: selectedSlot, action: action, assignments: assignments, hasTargetWindow: hasTargetWindow)
    }

    func hideAll() {
        radialMenu.hide()
        preview.hide()
    }
}
