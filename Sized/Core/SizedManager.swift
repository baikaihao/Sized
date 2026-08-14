import AppKit
import Combine
import OSLog

@MainActor
final class SizedManager: ObservableObject {
    static let shared = SizedManager()

    private let settings = SettingsStore.shared
    private let indicatorService = WindowActionIndicatorService()
    private let windowActionEngine = WindowActionEngine.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Sized", category: "Trigger")

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
    private var targetWindow: FocusedWindow?
    private var activeAssignments: AssignmentSettings = .default
    private var didStartEventTriggers = false
    private var didStartServices = false
    private var loopTimeoutTask: Task<Void, Never>?
    private var loopStartedAt: Date?
    private var interactionGeneration = 0
    private let cancellationGate = InteractionCancellationGate()

    private init() {}

    func start() {
        guard !didStartServices else { return }
        didStartServices = true

        AccessibilityManager.shared.refresh()
        if !AccessibilityManager.shared.isTrusted {
            AccessibilityManager.shared.startAutoRefresh()
        }

        startEventTriggers()
        applyPresentationSettings(settings.general)

        settings.$general
            .sink { [weak self] general in
                self?.applyPresentationSettings(general)
            }
            .store(in: &cancellables)

        settings.$trigger
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.restartEventTriggers()
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
        invalidateInteractionGeneration()
        isLoopActive = false
        targetWindow = nil
        stopLoopTimeout()
        mouseObserver.stop()
        stopEscapeMonitor()
        stopRightClickCancelMonitor()
        indicatorService.hideAll()
        StatusItemController.shared.applyVisibility(false)
        AccessibilityManager.shared.stopAutoRefresh()
        cancellables.removeAll()
        didStartServices = false
    }

    func refreshPermissions() {
        recoverStaleInteraction(reason: "refresh permissions")
        AccessibilityManager.shared.refresh()
        if AccessibilityManager.shared.isTrusted {
            restartEventTriggers()
        } else {
            AccessibilityManager.shared.startAutoRefresh()
        }
    }

    func refreshPresentationSettings(deferred: Bool = false) {
        guard deferred else {
            applyPresentationSettings(settings.general)
            return
        }

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            applyPresentationSettings(settings.general)
        }
    }

    private func applyPresentationSettings(_ general: GeneralSettings) {
        StatusItemController.shared.applyVisibility(general.showMenuBarIcon)
        NSApp.setActivationPolicy(general.hideDockIcon ? .accessory : .regular)
    }

    private func beginLoop() {
        if isLoopActive {
            if isLoopStale {
                forceResetInteraction(reason: "stale loop before new trigger")
            } else {
                log("begin loop ignored because loop is already active")
                return
            }
        }
        AccessibilityManager.shared.refresh()

        guard AccessibilityManager.shared.isTrusted else {
            AccessibilityManager.shared.requestAccess()
            log("begin loop blocked because accessibility is not trusted")
            return
        }

        interactionGeneration &+= 1
        cancellationGate.begin(generation: interactionGeneration)
        let sourceApplication = NSWorkspace.shared.frontmostApplication
        triggerOrigin = NSEvent.mouseLocation
        targetWindow = WindowUtility.targetWindow(
            mode: settings.behavior.windowTargetMode,
            point: triggerOrigin,
            fallbackApplication: sourceApplication
        )
        frontmostApplication = targetWindow?.application ?? sourceApplication
        activeAssignments = settings.assignments(for: frontmostApplication)
        selectedSlot = nil
        isLoopActive = true
        loopStartedAt = Date()
        log("begin loop at \(Int(triggerOrigin.x)),\(Int(triggerOrigin.y)) targetWindow=\(targetWindow == nil ? "none" : "available")")

        let hasWindow = windowActionEngine.hasTargetWindow(targetWindow)
        indicatorService.showRadialMenu(at: triggerOrigin, selectedSlot: nil, action: nil, assignments: activeAssignments, hasTargetWindow: hasWindow)
        mouseObserver.start(origin: triggerOrigin)
        if settings.behavior.escapeCancelsRadial {
            startEscapeMonitor()
        }
        if settings.behavior.rightClickCancelsRadial {
            startRightClickCancelMonitor()
        }
        startLoopTimeout()
    }

    private func endLoop(confirm: Bool) {
        guard isLoopActive else {
            log("end loop ignored because loop is not active confirm=\(confirm)")
            return
        }
        let generation = interactionGeneration
        let wasCancelled = cancellationGate.finish(generation: generation)
        let shouldConfirm = confirm && !wasCancelled
        interactionGeneration &+= 1
        defer {
            targetWindow = nil
            frontmostApplication = nil
            loopStartedAt = nil
        }

        let slot = selectedSlot
        isLoopActive = false
        log("end loop confirm=\(shouldConfirm) slot=\(slot.map { String(describing: $0) } ?? "none")")
        stopLoopTimeout()
        mouseObserver.stop()
        stopEscapeMonitor()
        stopRightClickCancelMonitor()
        indicatorService.hideAll()

        guard shouldConfirm, let slot else { return }
        let action = activeAssignments[slot]
        guard !action.isNoAction else { return }

        if let frontmostApplication {
            frontmostApplication.activate(options: [])
        }

        let success = windowActionEngine.perform(action, targetWindow: targetWindow)
        HapticFeedback.confirmed(enabled: success && settings.behavior.hapticFeedback)
    }

    private func updateSelection(_ slot: RadialMenuSlot?) {
        selectedSlot = slot
        let action = slot.map { activeAssignments[$0] }
        let hasWindow = windowActionEngine.hasTargetWindow(targetWindow)
        indicatorService.updateRadialMenu(selectedSlot: slot, action: action, assignments: activeAssignments, hasTargetWindow: hasWindow)

        if let action, let preview = windowActionEngine.preview(for: action, targetWindow: targetWindow) {
            indicatorService.preview.show(frame: WindowUtility.axRectToAppKit(preview.frame), style: preview.style)
        } else {
            indicatorService.preview.hide()
        }

        HapticFeedback.selectionChanged(enabled: settings.behavior.hapticFeedback)
    }

    private func startEventTriggers() {
        guard !didStartEventTriggers else { return }
        keybindTrigger.start()
        if settings.trigger.middleClickTrigger || settings.trigger.sideMouseButtonTrigger {
            middleClickTrigger.start()
        }
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

        let generation = interactionGeneration
        let cancellationGate = cancellationGate
        let mask = 1 << CGEventType.keyDown.rawValue
        let monitor = ActiveEventMonitor(mask: CGEventMask(mask)) { [weak self] type, event in
            guard type == .keyDown else { return .forward }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard keyCode == 53 else { return .forward }

            cancellationGate.cancel(generation: generation)
            Task { @MainActor in
                guard let self,
                      self.interactionGeneration == generation,
                      self.isLoopActive else { return }
                self.endLoop(confirm: false)
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

        let generation = interactionGeneration
        let cancellationGate = cancellationGate
        let mask = 1 << CGEventType.rightMouseDown.rawValue
        let monitor = ActiveEventMonitor(
            mask: CGEventMask(mask),
            placement: .headInsertEventTap,
            options: .defaultTap
        ) { [weak self] type, _ in
            guard type == .rightMouseDown else { return .forward }
            cancellationGate.cancel(generation: generation)
            Task { @MainActor in
                guard let self,
                      self.interactionGeneration == generation,
                      self.isLoopActive else { return }
                self.endLoop(confirm: false)
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

    private func startLoopTimeout() {
        stopLoopTimeout()

        let timeout = max(0.5, settings.trigger.timeoutSeconds)
        let generation = interactionGeneration
        loopTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled,
                  let self,
                  self.interactionGeneration == generation,
                  self.isLoopActive else { return }
            self.log("loop timeout fired")
            self.endLoop(confirm: false)
        }
    }

    private func stopLoopTimeout() {
        loopTimeoutTask?.cancel()
        loopTimeoutTask = nil
    }

    private var isLoopStale: Bool {
        guard let loopStartedAt else { return false }
        return Date().timeIntervalSince(loopStartedAt) > staleLoopTimeout
    }

    private var staleLoopTimeout: TimeInterval {
        max(
            1,
            settings.trigger.triggerDelayMilliseconds / 1000 +
            settings.trigger.timeoutSeconds +
            settings.behavior.previewAnimationSpeed +
            1
        )
    }

    private func recoverStaleInteraction(reason: String) {
        guard isLoopActive, isLoopStale else { return }
        forceResetInteraction(reason: reason)
    }

    private func forceResetInteraction(reason: String) {
        log("force reset interaction: \(reason)")
        invalidateInteractionGeneration()
        isLoopActive = false
        selectedSlot = nil
        targetWindow = nil
        frontmostApplication = nil
        loopStartedAt = nil
        stopLoopTimeout()
        mouseObserver.stop()
        stopEscapeMonitor()
        stopRightClickCancelMonitor()
        indicatorService.hideAll(immediately: true)
        keybindTrigger.resetState(reason: "manager force reset")
        middleClickTrigger.resetState(reason: "manager force reset")
    }

    private func invalidateInteractionGeneration() {
        cancellationGate.finish(generation: interactionGeneration)
        interactionGeneration &+= 1
    }

    private func log(_ message: String) {
        guard settings.behavior.resizeDiagnostics else { return }
        logger.info("\(message, privacy: .public)")
    }
}

private nonisolated final class InteractionCancellationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var activeGeneration = 0
    private var active = false
    private var cancelled = false

    func begin(generation: Int) {
        lock.lock()
        activeGeneration = generation
        active = true
        cancelled = false
        lock.unlock()
    }

    func cancel(generation: Int) {
        lock.lock()
        if active, activeGeneration == generation {
            cancelled = true
        }
        lock.unlock()
    }

    @discardableResult
    func finish(generation: Int) -> Bool {
        lock.lock()
        let wasCancelled = active && activeGeneration == generation && cancelled
        if activeGeneration == generation {
            active = false
            cancelled = false
        }
        lock.unlock()
        return wasCancelled
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
