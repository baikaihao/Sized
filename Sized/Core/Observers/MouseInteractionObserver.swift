import AppKit

@MainActor
protocol MouseInteractionObserverDelegate: AnyObject {
    func mouseSelectionDidChange(to slot: RadialMenuSlot?)
    func mouseDidClick()
}

final class MouseInteractionObserver {
    weak var delegate: MouseInteractionObserverDelegate?

    private var moveEventTap: CFMachPort?
    private var moveRunLoopSource: CFRunLoopSource?
    private var clickMonitor: ActiveEventMonitor?
    private var origin = CGPoint.zero
    private var isActive = false
    private var selectedSlot: RadialMenuSlot?
    private var directionalActionDistance: CGFloat = 20

    private let noActionDistance: CGFloat = 3

    func start(origin: CGPoint) {
        self.origin = origin
        let style = SettingsStore.shared.wheelStyle
        directionalActionDistance = max(
            noActionDistance + 2,
            CGFloat(style.size - style.thickness * 2) / 2
        )
        selectedSlot = nil
        isActive = true

        startMoveMonitor()

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
        stopMoveMonitor()
        clickMonitor?.stop()
        clickMonitor = nil
        selectedSlot = nil
    }

    private func startMoveMonitor() {
        stopMoveMonitor()

        let mask = (1 << CGEventType.mouseMoved.rawValue) |
                   (1 << CGEventType.leftMouseDragged.rawValue) |
                   (1 << CGEventType.otherMouseDragged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let observer = Unmanaged<MouseInteractionObserver>.fromOpaque(refcon).takeUnretainedValue()
                DispatchQueue.main.async {
                    observer.handleMouseMoved(location: NSEvent.mouseLocation)
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: refcon
        ) else { return }

        moveEventTap = tap
        moveRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource = moveRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopMoveMonitor() {
        if let eventTap = moveEventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = moveRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        moveEventTap = nil
        moveRunLoopSource = nil
    }

    private func handleMouseMoved(location: CGPoint) {
        guard isActive else { return }
        let delta = CGSize(width: location.x - origin.x, height: location.y - origin.y)
        let slot = RadialMenuSlot.nearestSlot(delta: delta, directionalThreshold: directionalActionDistance, noActionThreshold: noActionDistance)
        if slot != selectedSlot {
            selectedSlot = slot
            delegate?.mouseSelectionDidChange(to: slot)
        }
    }
}
