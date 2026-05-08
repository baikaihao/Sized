import AppKit

final class PassiveEventMonitor {
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent) -> Void
    private var monitor: Any?

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit {
        stop()
    }
}
