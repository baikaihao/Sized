import AppKit
import CoreGraphics

@MainActor
protocol KeybindTriggerDelegate: AnyObject {
    func triggerDidBegin()
    func triggerDidEnd(confirm: Bool)
    func triggerDidCancel()
    func triggerMonitorDidFailToStart()
}

final class KeybindTrigger {
    weak var delegate: KeybindTriggerDelegate?

    private var monitor: ActiveEventMonitor?
    private var isTriggerDown = false
    private var pendingWorkItem: DispatchWorkItem?
    private var lastTriggerDate: Date?
    private var settings: SettingsStore { .shared }

    func start() {
        guard monitor == nil else { return }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let monitor = ActiveEventMonitor(mask: CGEventMask(mask)) { [weak self] type, event in
            DispatchQueue.main.async {
                self?.handle(type: type, event: event)
            }
            return .forward
        }
        self.monitor = monitor
        if !monitor.start() {
            self.monitor = nil
            delegate?.triggerMonitorDidFailToStart()
        }
    }

    func stop() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        monitor?.stop()
        monitor = nil
        isTriggerDown = false
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == 53, isTriggerDown {
                delegate?.triggerDidCancel()
                isTriggerDown = false
            }
            return
        }

        guard type == .flagsChanged else { return }
        let flags = event.flags
        let optionDown = flags.contains(.maskAlternate)

        if optionDown && !isTriggerDown {
            beginTrigger()
        } else if !optionDown && isTriggerDown {
            pendingWorkItem?.cancel()
            pendingWorkItem = nil
            isTriggerDown = false
            delegate?.triggerDidEnd(confirm: true)
        }
    }

    private func beginTrigger() {
        let now = Date()
        if settings.trigger.doubleTapTrigger {
            guard let lastTriggerDate, now.timeIntervalSince(lastTriggerDate) < 0.35 else {
                lastTriggerDate = now
                return
            }
        }

        isTriggerDown = true
        lastTriggerDate = now

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.delegate?.triggerDidBegin()
            }
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.trigger.triggerDelayMilliseconds / 1000, execute: workItem)

        DispatchQueue.main.asyncAfter(deadline: .now() + settings.trigger.timeoutSeconds) { [weak self] in
            guard let self, self.isTriggerDown else { return }
            self.isTriggerDown = false
            self.pendingWorkItem?.cancel()
            self.pendingWorkItem = nil
            self.delegate?.triggerDidCancel()
        }
    }
}
