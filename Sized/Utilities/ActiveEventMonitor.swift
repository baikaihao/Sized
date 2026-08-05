import AppKit
import CoreGraphics
import OSLog

nonisolated enum EventMonitorDecision {
    case forward
    case ignore
}

nonisolated final class ActiveEventMonitor {
    private let core: EventTapCore

    init(
        name: String = "ActiveEventMonitor",
        mask: CGEventMask,
        placement: CGEventTapPlacement = .headInsertEventTap,
        options: CGEventTapOptions = .defaultTap,
        handler: @escaping (CGEventType, CGEvent) -> EventMonitorDecision
    ) {
        core = EventTapCore(
            name: name,
            mask: mask,
            placement: placement,
            options: options,
            handler: handler
        )
    }

    @discardableResult
    func start() -> Bool {
        core.start()
    }

    func stop() {
        core.stop()
    }

    deinit {
        stop()
    }
}

private nonisolated final class EventTapCore: @unchecked Sendable {
    private let name: String
    private let mask: CGEventMask
    private let placement: CGEventTapPlacement
    private let options: CGEventTapOptions
    private let handler: (CGEventType, CGEvent) -> EventMonitorDecision
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Sized", category: "Trigger")
    private let stateLock = NSLock()

    private var thread: Thread?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var reenableTimer: CFRunLoopTimer?
    private var stopRequested = false

    init(
        name: String,
        mask: CGEventMask,
        placement: CGEventTapPlacement,
        options: CGEventTapOptions,
        handler: @escaping (CGEventType, CGEvent) -> EventMonitorDecision
    ) {
        self.name = name
        self.mask = mask
        self.placement = placement
        self.options = options
        self.handler = handler
    }

    func start() -> Bool {
        stateLock.lock()
        if eventTap != nil {
            stateLock.unlock()
            return true
        }
        if thread != nil {
            stateLock.unlock()
            return false
        }
        stopRequested = false

        let startup = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in
            defer {
                stateLock.lock()
                if self.thread === Thread.current {
                    self.thread = nil
                }
                stateLock.unlock()
            }

            let currentRunLoop = CFRunLoopGetCurrent()
            let refcon = Unmanaged.passUnretained(self).toOpaque()

            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: placement,
                options: options,
                eventsOfInterest: mask,
                callback: { _, type, event, refcon in
                    guard let refcon else { return Unmanaged.passUnretained(event) }
                    let core = Unmanaged<EventTapCore>.fromOpaque(refcon).takeUnretainedValue()
                    return autoreleasepool {
                        core.process(type: type, event: event)
                    }
                },
                userInfo: refcon
            ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
                startup.signal()
                return
            }

            stateLock.lock()
            guard !stopRequested else {
                stateLock.unlock()
                CFRunLoopSourceInvalidate(source)
                CFMachPortInvalidate(tap)
                startup.signal()
                return
            }
            eventTap = tap
            runLoopSource = source
            runLoop = currentRunLoop
            stateLock.unlock()

            CFRunLoopAddSource(currentRunLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            startup.signal()
            CFRunLoopRun()
            tearDownOnTapThread()
        }
        thread.name = "Sized.\(name)"
        thread.qualityOfService = .userInteractive
        self.thread = thread
        stateLock.unlock()

        thread.start()
        guard startup.wait(timeout: .now() + 1) == .success else {
            stateLock.lock()
            stopRequested = true
            let runLoop = self.runLoop
            stateLock.unlock()
            if let runLoop {
                requestStop(for: runLoop)
            }
            logger.error("\(self.name, privacy: .public) event tap startup timed out")
            return false
        }

        stateLock.lock()
        let didStart = eventTap != nil
        stateLock.unlock()
        return didStart
    }

    func stop() {
        stateLock.lock()
        stopRequested = true
        guard let runLoop else {
            stateLock.unlock()
            return
        }
        let eventTap = self.eventTap
        stateLock.unlock()

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if CFRunLoopGetCurrent() === runLoop {
            CFRunLoopStop(runLoop)
        } else {
            requestStop(for: runLoop)
            CFRunLoopStop(runLoop)
            CFRunLoopWakeUp(runLoop)
        }
    }

    private func requestStop(for runLoop: CFRunLoop) {
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
            CFRunLoopStop(runLoop)
        }
        CFRunLoopWakeUp(runLoop)
    }

    private func process(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            scheduleReenable(disabledBy: type)
            return Unmanaged.passUnretained(event)
        }

        let decision = handler(type, event)
        if options == .listenOnly {
            return Unmanaged.passUnretained(event)
        }

        switch decision {
        case .forward:
            return Unmanaged.passUnretained(event)
        case .ignore:
            return nil
        }
    }

    private func scheduleReenable(disabledBy type: CGEventType) {
        guard reenableTimer == nil, let eventTap else { return }
        logger.warning("\(self.name, privacy: .public) event tap disabled by \(String(describing: type), privacy: .public); retrying after backoff")

        let timer = CFRunLoopTimerCreateWithHandler(
            kCFAllocatorDefault,
            CFAbsoluteTimeGetCurrent() + 0.25,
            0,
            0,
            0
        ) { [weak self] _ in
            guard let self else { return }
            self.reenableTimer = nil
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        reenableTimer = timer
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .commonModes)
    }

    private func tearDownOnTapThread() {
        if let reenableTimer {
            CFRunLoopTimerInvalidate(reenableTimer)
        }
        reenableTimer = nil

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource, let runLoop {
            CFRunLoopRemoveSource(runLoop, runLoopSource, .commonModes)
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }

        stateLock.lock()
        eventTap = nil
        runLoopSource = nil
        runLoop = nil
        stateLock.unlock()
    }
}
