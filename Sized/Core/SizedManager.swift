import AppKit
import Combine

@MainActor
final class SizedManager: ObservableObject {
    static let shared = SizedManager()

    private let settings = SettingsStore.shared
    private let indicatorService = WindowActionIndicatorService()
    private let windowActionEngine = WindowActionEngine.shared

    private lazy var keybindTrigger: KeybindTrigger = {
        let trigger = KeybindTrigger()
        trigger.delegate = self
        return trigger
    }()

    private lazy var middleClickTrigger: MiddleClickTrigger = {
        let trigger = MiddleClickTrigger()
        trigger.delegate = self
        return trigger
    }()

    private lazy var mouseObserver: MouseInteractionObserver = {
        let observer = MouseInteractionObserver()
        observer.delegate = self
        return observer
    }()

    private var escapeMonitor: ActiveEventMonitor?
    private var rightClickCancelMonitor: ActiveEventMonitor?
    private var cancellables = Set<AnyCancellable>()
    private var isLoopActive = false
    private var triggerOrigin = CGPoint.zero
    private var selectedSlot: RadialMenuSlot?
    private var frontmostApplication: NSRunningApplication?
    private var didStartEventTriggers = false

    private init() {}

    func start() {
        AccessibilityManager.shared.refresh()
        if !AccessibilityManager.shared.isTrusted {
            AccessibilityManager.shared.startAutoRefresh()
        }

        startEventTriggers()
        StatusItemController.shared.applyVisibility(settings.general.showMenuBarIcon)

        settings.$general
            .sink { general in
                StatusItemController.shared.applyVisibility(general.showMenuBarIcon)
                NSApp.setActivationPolicy(general.hideDockIcon ? .accessory : .regular)
            }
            .store(in: &cancellables)

        AccessibilityManager.shared.$isTrusted
            .removeDuplicates()
            .sink { [weak self] isTrusted in
                guard isTrusted else { return }
                self?.restartEventTriggers()
            }
            .store(in: &cancellables)
    }

    func stop() {
        stopEventTriggers()
        mouseObserver.stop()
        stopEscapeMonitor()
        stopRightClickCancelMonitor()
        indicatorService.hideAll()
        AccessibilityManager.shared.stopAutoRefresh()
    }

    func refreshPermissions() {
        AccessibilityManager.shared.refresh()
        if AccessibilityManager.shared.isTrusted {
            restartEventTriggers()
        } else {
            AccessibilityManager.shared.startAutoRefresh()
        }
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    private func beginLoop() {
        guard !isLoopActive else { return }
        AccessibilityManager.shared.refresh()

        guard AccessibilityManager.shared.isTrusted else {
            AccessibilityManager.shared.requestAccess()
            return
        }

        frontmostApplication = NSWorkspace.shared.frontmostApplication
        triggerOrigin = NSEvent.mouseLocation
        selectedSlot = nil
        isLoopActive = true

        let hasWindow = windowActionEngine.hasFocusedWindow()
        indicatorService.showRadialMenu(at: triggerOrigin, selectedSlot: nil, action: nil, hasTargetWindow: hasWindow)
        mouseObserver.start(origin: triggerOrigin)
        if settings.behavior.escapeCancelsRadial {
            startEscapeMonitor()
        }
        if settings.behavior.rightClickCancelsRadial {
            startRightClickCancelMonitor()
        }
    }

    private func endLoop(confirm: Bool) {
        guard isLoopActive else { return }

        let slot = selectedSlot
        isLoopActive = false
        mouseObserver.stop()
        stopEscapeMonitor()
        stopRightClickCancelMonitor()
        indicatorService.hideAll()

        guard confirm, let slot else { return }
        let action = settings.assignments[slot]
        guard action.kind != .none else { return }

        if let frontmostApplication {
            frontmostApplication.activate(options: [])
        }

        let success = windowActionEngine.perform(action)
        HapticFeedback.confirmed(enabled: success && settings.behavior.hapticFeedback)
    }

    private func updateSelection(_ slot: RadialMenuSlot?) {
        selectedSlot = slot
        let action = slot.map { settings.assignments[$0] }
        let hasWindow = windowActionEngine.hasFocusedWindow()
        indicatorService.updateRadialMenu(selectedSlot: slot, action: action, hasTargetWindow: hasWindow)

        if let action, let frame = windowActionEngine.targetFrame(for: action) {
            indicatorService.preview.show(frame: WindowUtility.axRectToAppKit(frame))
        } else {
            indicatorService.preview.hide()
        }

        HapticFeedback.selectionChanged(enabled: settings.behavior.hapticFeedback)
    }

    private func startEventTriggers() {
        guard !didStartEventTriggers else { return }
        keybindTrigger.start()
        middleClickTrigger.start()
        didStartEventTriggers = true
    }

    private func stopEventTriggers() {
        keybindTrigger.stop()
        middleClickTrigger.stop()
        didStartEventTriggers = false
    }

    private func restartEventTriggers() {
        stopEventTriggers()
        startEventTriggers()
    }

    private func startEscapeMonitor() {
        stopEscapeMonitor()

        let mask = 1 << CGEventType.keyDown.rawValue
        let monitor = ActiveEventMonitor(mask: CGEventMask(mask)) { [weak self] type, event in
            guard type == .keyDown else { return .forward }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard keyCode == 53 else { return .forward }

            Task { @MainActor in
                self?.endLoop(confirm: false)
            }
            return .ignore
        }

        escapeMonitor = monitor
        if !monitor.start() {
            escapeMonitor = nil
            AccessibilityManager.shared.requestAccess()
        }
    }

    private func stopEscapeMonitor() {
        escapeMonitor?.stop()
        escapeMonitor = nil
    }

    private func startRightClickCancelMonitor() {
        stopRightClickCancelMonitor()

        let mask = 1 << CGEventType.rightMouseDown.rawValue
        let monitor = ActiveEventMonitor(mask: CGEventMask(mask)) { [weak self] type, event in
            guard type == .rightMouseDown else { return .forward }
            Task { @MainActor in
                self?.endLoop(confirm: false)
            }
            return .forward
        }

        rightClickCancelMonitor = monitor
        if !monitor.start() {
            rightClickCancelMonitor = nil
        }
    }

    private func stopRightClickCancelMonitor() {
        rightClickCancelMonitor?.stop()
        rightClickCancelMonitor = nil
    }
}

extension SizedManager: KeybindTriggerDelegate {
    func triggerDidBegin() {
        beginLoop()
    }

    func triggerDidEnd(confirm: Bool) {
        endLoop(confirm: confirm)
    }

    func triggerDidCancel() {
        endLoop(confirm: false)
    }

    func triggerMonitorDidFailToStart() {
        AccessibilityManager.shared.requestAccess()
    }
}

extension SizedManager: MiddleClickTriggerDelegate {
    func middleClickDidBegin() {
        beginLoop()
    }

    func middleClickDidEnd(confirm: Bool) {
        endLoop(confirm: confirm)
    }

    func middleClickMonitorDidFailToStart() {
        AccessibilityManager.shared.requestAccess()
    }
}

extension SizedManager: MouseInteractionObserverDelegate {
    func mouseSelectionDidChange(to slot: RadialMenuSlot?) {
        updateSelection(slot)
    }

    func mouseDidClick() {
        guard settings.behavior.confirmationMode == .click else { return }
        endLoop(confirm: true)
    }
}
