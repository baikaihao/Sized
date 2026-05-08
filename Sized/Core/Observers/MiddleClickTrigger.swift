import AppKit
import CoreGraphics

@MainActor
protocol MiddleClickTriggerDelegate: AnyObject {
    func middleClickDidBegin()
    func middleClickDidEnd(confirm: Bool)
    func middleClickMonitorDidFailToStart()
}

final class MiddleClickTrigger {
    weak var delegate: MiddleClickTriggerDelegate?

    private var monitor: ActiveEventMonitor?
    private var isDown = false
    private var settings: SettingsStore { .shared }

    func start() {
        guard monitor == nil else { return }
        let mask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
        let monitor = ActiveEventMonitor(mask: CGEventMask(mask)) { [weak self] type, event in
            guard let self else { return .forward }
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            guard button == 2 else { return .forward }

            DispatchQueue.main.async {
                self.handle(type: type, button: button)
            }
            return self.settings.trigger.middleClickTrigger ? .ignore : .forward
        }
        self.monitor = monitor
        if !monitor.start() {
            self.monitor = nil
            delegate?.middleClickMonitorDidFailToStart()
        }
    }

    func stop() {
        monitor?.stop()
        monitor = nil
        isDown = false
    }

    private func handle(type: CGEventType, button: Int64) {
        guard settings.trigger.middleClickTrigger, button == 2 else { return }

        if type == .otherMouseDown, !isDown {
            isDown = true
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.trigger.triggerDelayMilliseconds / 1000) { [weak self] in
                guard let self, self.isDown else { return }
                self.delegate?.middleClickDidBegin()
            }
            return
        }

        if type == .otherMouseUp, isDown {
            isDown = false
            delegate?.middleClickDidEnd(confirm: true)
        }
    }
}
