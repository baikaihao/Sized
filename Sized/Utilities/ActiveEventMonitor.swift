import AppKit
import CoreGraphics

enum EventMonitorDecision {
    case forward
    case ignore
}

final class ActiveEventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let mask: CGEventMask
    private let handler: (CGEventType, CGEvent) -> EventMonitorDecision

    init(mask: CGEventMask, handler: @escaping (CGEventType, CGEvent) -> EventMonitorDecision) {
        self.mask = mask
        self.handler = handler
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<ActiveEventMonitor>.fromOpaque(refcon).takeUnretainedValue()
                switch monitor.handler(type, event) {
                case .forward:
                    return Unmanaged.passRetained(event)
                case .ignore:
                    return nil
                }
            },
            userInfo: refcon
        ) else { return false }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    deinit {
        stop()
    }
}
