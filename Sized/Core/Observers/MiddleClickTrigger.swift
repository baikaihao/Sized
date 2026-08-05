import AppKit
import CoreGraphics
import OSLog

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
    private var activeButtonStartedAt: Date?
    private var pendingBeginWorkItem: DispatchWorkItem?
    private var activeButtonResetWorkItem: DispatchWorkItem?
    private var monitorGeneration = 0
    private var activeButtonGeneration = 0
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Sized", category: "Trigger")
    private var settings: SettingsStore { .shared }

    func start() {
        guard monitor == nil else { return }
        var configuredButtons = Set<Int64>()
        if settings.trigger.middleClickTrigger {
            configuredButtons.insert(2)
        }
        if settings.trigger.sideMouseButtonTrigger {
            configuredButtons.insert(Int64(settings.trigger.sideMouseButtonNumber))
        }
        guard !configuredButtons.isEmpty else { return }

        monitorGeneration &+= 1
        let generation = monitorGeneration
        let mask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
        let monitor = ActiveEventMonitor(name: "MiddleClickTrigger", mask: CGEventMask(mask)) { [weak self] type, event in
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            guard configuredButtons.contains(button) else { return .forward }

            DispatchQueue.main.async {
                guard let self, self.monitorGeneration == generation else { return }
                self.handle(type: type, button: button)
            }
            return .ignore
        }
        self.monitor = monitor
        if !monitor.start() {
            self.monitor = nil
            delegate?.middleClickMonitorDidFailToStart()
            log("middle click monitor failed to start")
        } else {
            log("middle click monitor started")
        }
    }

    func stop() {
        monitorGeneration &+= 1
        resetState(reason: "stop")
        monitor?.stop()
        monitor = nil
    }

    func resetState(reason: String) {
        if activeButton != nil {
            log("middle click reset state: \(reason)")
        }
        activeButtonGeneration &+= 1
        pendingBeginWorkItem?.cancel()
        pendingBeginWorkItem = nil
        activeButtonResetWorkItem?.cancel()
        activeButtonResetWorkItem = nil
        activeButton = nil
        activeButtonStartedAt = nil
    }

    private func handle(type: CGEventType, button: Int64) {
        guard isConfiguredTriggerButton(button) else { return }

        if type == .otherMouseDown {
            if activeButton != nil, isActiveButtonStale {
                resetState(reason: "stale active button before new down")
            }

            guard activeButton == nil else {
                log("middle click down ignored because button \(button) is already active")
                return
            }

            activeButton = button
            activeButtonStartedAt = Date()
            activeButtonGeneration &+= 1
            let generation = activeButtonGeneration
            log("middle click down button \(button)")

            let beginWorkItem = DispatchWorkItem { [weak self] in
                guard let self,
                      self.activeButtonGeneration == generation,
                      self.activeButton == button else { return }
                self.log("middle click begin loop button \(button)")
                self.delegate?.middleClickDidBegin()
            }
            pendingBeginWorkItem = beginWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.trigger.triggerDelayMilliseconds / 1000, execute: beginWorkItem)

            let resetWorkItem = DispatchWorkItem { [weak self] in
                guard let self,
                      self.activeButtonGeneration == generation,
                      self.activeButton == button else { return }
                self.resetState(reason: "watchdog timeout waiting for mouse up")
            }
            activeButtonResetWorkItem = resetWorkItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + settings.trigger.triggerDelayMilliseconds / 1000 + settings.trigger.timeoutSeconds + 1,
                execute: resetWorkItem
            )
            return
        }

        if type == .otherMouseUp, activeButton == button {
            log("middle click up button \(button)")
            activeButtonGeneration &+= 1
            activeButton = nil
            activeButtonStartedAt = nil
            pendingBeginWorkItem?.cancel()
            pendingBeginWorkItem = nil
            activeButtonResetWorkItem?.cancel()
            activeButtonResetWorkItem = nil
            delegate?.middleClickDidEnd(confirm: true)
        }
    }

    private var isActiveButtonStale: Bool {
        guard let activeButtonStartedAt else { return false }
        let timeout = settings.trigger.triggerDelayMilliseconds / 1000 + settings.trigger.timeoutSeconds + 1
        return Date().timeIntervalSince(activeButtonStartedAt) > max(1, timeout)
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

    private func log(_ message: String) {
        guard settings.behavior.resizeDiagnostics else { return }
        logger.info("\(message, privacy: .public)")
    }
}
