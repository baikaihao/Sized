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
    private var activeButton: Int64?
    private var settings: SettingsStore { .shared }

    func start() {
        guard monitor == nil else { return }
        let mask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
        let monitor = ActiveEventMonitor(mask: CGEventMask(mask)) { [weak self] type, event in
            guard let self else { return .forward }
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            guard self.isConfiguredTriggerButton(button) else { return .forward }

            DispatchQueue.main.async {
                self.handle(type: type, button: button)
            }
            return .ignore
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
        activeButton = nil
    }

    private func handle(type: CGEventType, button: Int64) {
        guard isConfiguredTriggerButton(button) else { return }

        if type == .otherMouseDown, activeButton == nil {
            activeButton = button
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.trigger.triggerDelayMilliseconds / 1000) { [weak self] in
                guard let self, self.activeButton == button else { return }
                self.delegate?.middleClickDidBegin()
            }
            return
        }

        if type == .otherMouseUp, activeButton == button {
            activeButton = nil
            delegate?.middleClickDidEnd(confirm: true)
        }
    }

    private func isConfiguredTriggerButton(_ button: Int64) -> Bool {
        let trigger = settings.trigger
        if trigger.middleClickTrigger, button == 2 {
            return true
        }
        if trigger.sideMouseButtonTrigger, button == Int64(trigger.sideMouseButtonNumber) {
            return true
        }
        return false
    }
}
