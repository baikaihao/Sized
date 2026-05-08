import AppKit

@MainActor
protocol MouseInteractionObserverDelegate: AnyObject {
    func mouseSelectionDidChange(to slot: RadialMenuSlot?)
    func mouseDidClick()
}

final class MouseInteractionObserver {
    weak var delegate: MouseInteractionObserverDelegate?

    private var moveMonitor: PassiveEventMonitor?
    private var clickMonitor: ActiveEventMonitor?
    private var origin = CGPoint.zero
    private var isActive = false
    private var selectedSlot: RadialMenuSlot?
    private var directionalActionDistance: CGFloat = 20

    private let noActionDistance: CGFloat = 10

    func start(origin: CGPoint) {
        self.origin = origin
        let style = SettingsStore.shared.wheelStyle
        directionalActionDistance = max(
            noActionDistance + 2,
            CGFloat(style.size - style.thickness * 2) / 2
        )
        selectedSlot = nil
        isActive = true

        moveMonitor = PassiveEventMonitor(mask: [.mouseMoved, .otherMouseDragged, .leftMouseDragged]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleMouseMoved(location: NSEvent.mouseLocation)
            }
        }
        moveMonitor?.start()

        let mask = 1 << CGEventType.leftMouseDown.rawValue
        clickMonitor = ActiveEventMonitor(mask: CGEventMask(mask)) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.delegate?.mouseDidClick()
            }
            return .ignore
        }
        clickMonitor?.start()
    }

    func stop() {
        isActive = false
        moveMonitor?.stop()
        clickMonitor?.stop()
        moveMonitor = nil
        clickMonitor = nil
        selectedSlot = nil
    }

    private func handleMouseMoved(location: CGPoint) {
        guard isActive else { return }
        let delta = CGSize(width: location.x - origin.x, height: origin.y - location.y)
        let slot = RadialMenuSlot.nearestSlot(delta: delta, directionalThreshold: directionalActionDistance, noActionThreshold: noActionDistance)
        if slot != selectedSlot {
            selectedSlot = slot
            delegate?.mouseSelectionDidChange(to: slot)
        }
    }
}
