import AppKit
import OSLog

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
    private var pendingLocation: CGPoint?
    private var isMoveUpdateScheduled = false
    private var interactionGeneration = 0
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Sized", category: "Trigger")

    private let noActionDistance: CGFloat = 3

    func start(origin: CGPoint) {
        interactionGeneration &+= 1
        let generation = interactionGeneration
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
            Task { @MainActor [weak self] in
                guard let self,
                      self.interactionGeneration == generation,
                      self.isActive else { return }
                self.delegate?.mouseDidClick()
            }
            return .ignore
        }
        clickMonitor?.start()
    }

    func stop() {
        interactionGeneration &+= 1
        isActive = false
        stopMoveMonitor()
        clickMonitor?.stop()
        clickMonitor = nil
        selectedSlot = nil
        pendingLocation = nil
        isMoveUpdateScheduled = false
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
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let observer = Unmanaged<MouseInteractionObserver>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    observer.reenableMoveEventTap(disabledBy: type)
                    return Unmanaged.passUnretained(event)
                }
                observer.scheduleMouseMoved()
                return Unmanaged.passUnretained(event)
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
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        if let eventTap = moveEventTap {
            CFMachPortInvalidate(eventTap)
        }
        moveEventTap = nil
        moveRunLoopSource = nil
    }

    private func scheduleMouseMoved() {
        pendingLocation = NSEvent.mouseLocation
        guard !isMoveUpdateScheduled else { return }

        isMoveUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let location = self.pendingLocation
            self.pendingLocation = nil
            self.isMoveUpdateScheduled = false
            guard let location else { return }
            self.handleMouseMoved(location: location)
        }
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

    private func reenableMoveEventTap(disabledBy type: CGEventType) {
        guard let moveEventTap else { return }
        logger.warning("MouseInteractionObserver event tap disabled by \(String(describing: type), privacy: .public); re-enabling")
        CGEvent.tapEnable(tap: moveEventTap, enable: true)
    }
}
