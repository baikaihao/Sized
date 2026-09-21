import AppKit
import CoreGraphics
import OSLog

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
    private var currentOptionKeycode: Int64 = 0
    private var currentTriggerKeycode: Int64 = 0
    private var pendingBeginTask: Task<Void, Never>?
    private var lastTriggerDate: Date?
    private var triggerStartedAt: Date?
    private var monitorGeneration = 0
    private var triggerGeneration = 0
    private var cachedKeybindingDisplayName = ""
    private var cachedKeybinding = ParsedKeybinding(modifiers: [], keyCode: 0, isValid: false)
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Sized", category: "Trigger")
    private var settings: SettingsStore { .shared }
    
    private struct ParsedKeybinding {
        let modifiers: CGEventFlags
        let keyCode: Int
        let isValid: Bool
    }

    func start() {
        guard monitor == nil else { return }
        monitorGeneration &+= 1
        let generation = monitorGeneration
        let useOptionAsTrigger = settings.trigger.useOptionAsTrigger
        let keybinding: ParsedKeybinding = useOptionAsTrigger
            ? ParsedKeybinding(modifiers: [], keyCode: 0, isValid: false)
            : currentKeybinding()
        let mask: Int
        if useOptionAsTrigger {
            mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        } else {
            mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        }
        let monitor = ActiveEventMonitor(
            name: "KeybindTrigger",
            mask: CGEventMask(mask),
            placement: .headInsertEventTap,
            options: .defaultTap
        ) { [weak self] type, event in
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            let isAutorepeat = type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) != 0

            // 自定义快捷键模式下吞掉触发键本身，消除系统提示音并阻止透传给前台应用
            var swallow = false
            if !useOptionAsTrigger, keybinding.isValid,
               (type == .keyDown || type == .keyUp),
               keyCode == Int64(keybinding.keyCode) {
                let eventModifiers = flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])
                swallow = eventModifiers == keybinding.modifiers
            }

            if !isAutorepeat {
                DispatchQueue.main.async {
                    guard let self, self.monitorGeneration == generation else { return }
                    self.handle(type: type, keyCode: keyCode, flags: flags)
                }
            }
            return swallow ? .ignore : .forward
        }
        self.monitor = monitor
        if !monitor.start() {
            self.monitor = nil
            delegate?.triggerMonitorDidFailToStart()
            log("keybind monitor failed to start")
        } else {
            log("keybind monitor started")
        }
    }

    func stop() {
        monitorGeneration &+= 1
        resetState(reason: "stop")
        monitor?.stop()
        monitor = nil
    }

    func resetState(reason: String) {
        if isTriggerDown {
            log("keybind reset state: \(reason)")
        }
        triggerGeneration &+= 1
        pendingBeginTask?.cancel()
        pendingBeginTask = nil
        isTriggerDown = false
        currentOptionKeycode = 0
        currentTriggerKeycode = 0
        triggerStartedAt = nil
    }

    private func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags) {
        if isTriggerDown, isTriggerStale {
            resetState(reason: "stale trigger before event \(String(describing: type))")
        }

        if type == .keyDown {
            if keyCode == 53, isTriggerDown, settings.behavior.escapeCancelsRadial {
                delegate?.triggerDidCancel()
                resetState(reason: "escape cancel")
                return
            }

            if settings.trigger.useOptionAsTrigger,
               isTriggerDown,
               settings.behavior.otherKeyCancelsRadial {
                delegate?.triggerDidCancel()
                resetState(reason: "other key cancel")
                return
            }

            if !settings.trigger.useOptionAsTrigger {
                let keybinding = currentKeybinding()
                let eventModifiers = flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])

                if keybinding.isValid &&
                   keyCode == Int64(keybinding.keyCode) &&
                   eventModifiers == keybinding.modifiers &&
                   !isTriggerDown {
                    currentTriggerKeycode = keyCode
                    beginTrigger()
                    return
                }

                if !isTriggerDown { return }

                if keyCode == Int64(keybinding.keyCode) && eventModifiers == keybinding.modifiers {
                    return
                } else {
                    resetState(reason: "different key down while active")
                    if settings.behavior.otherKeyCancelsRadial {
                        delegate?.triggerDidCancel()
                    } else {
                        delegate?.triggerDidEnd(confirm: true)
                    }
                }
            }
            return
        }

        if type == .keyUp {
            guard isTriggerDown, !settings.trigger.useOptionAsTrigger else { return }
            if keyCode == currentTriggerKeycode {
                resetState(reason: "key up")
                delegate?.triggerDidEnd(confirm: true)
            }
            return
        }

        guard type == .flagsChanged else { return }

        let optionDown = flags.contains(.maskAlternate)
        let isLeftOption = keyCode == 58
        let isRightOption = keyCode == 61

        if settings.trigger.useOptionAsTrigger {
            let side = settings.trigger.optionSide
            let matchesSide: Bool
            if optionDown {
                switch side {
                case .left:  matchesSide = isLeftOption
                case .right: matchesSide = isRightOption
                case .both:  matchesSide = isLeftOption || isRightOption
                }
            } else {
                switch side {
                case .left:  matchesSide = currentOptionKeycode == 58
                case .right: matchesSide = currentOptionKeycode == 61
                case .both:  matchesSide = currentOptionKeycode == 58 || currentOptionKeycode == 61
                }
            }

            if optionDown && matchesSide && !isTriggerDown {
                currentOptionKeycode = keyCode
                beginTrigger()
            } else if !optionDown && matchesSide && isTriggerDown {
                resetState(reason: "option up")
                delegate?.triggerDidEnd(confirm: true)
            }
        } else if isTriggerDown {
            let keybinding = currentKeybinding()
            guard keybinding.isValid else { return }
            let triggerModifiers = keybinding.modifiers
            let currentModifiers = flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])
            if !triggerModifiers.isEmpty && currentModifiers.intersection(triggerModifiers).isEmpty {
                resetState(reason: "modifier released")
                delegate?.triggerDidEnd(confirm: true)
            }
        }
    }

    private func currentKeybinding() -> ParsedKeybinding {
        let displayName = settings.trigger.triggerKeyDisplayName
        if displayName != cachedKeybindingDisplayName {
            cachedKeybindingDisplayName = displayName
            cachedKeybinding = parseKeybinding(displayName)
        }
        return cachedKeybinding
    }
    
    private func parseKeybinding(_ displayName: String) -> ParsedKeybinding {
        var modifiers: CGEventFlags = []
        var keyChar: String?
        
        if displayName.contains("⌃") { modifiers.insert(.maskControl) }
        if displayName.contains("⌥") { modifiers.insert(.maskAlternate) }
        if displayName.contains("⇧") { modifiers.insert(.maskShift) }
        if displayName.contains("⌘") { modifiers.insert(.maskCommand) }
        
        let modifierSymbols = ["⌃", "⌥", "⇧", "⌘", "⇪"]
        var remaining = displayName
        for symbol in modifierSymbols {
            remaining = remaining.replacingOccurrences(of: symbol, with: "")
        }
        remaining = remaining.trimmingCharacters(in: .whitespaces)
        
        if !remaining.isEmpty {
            keyChar = remaining.uppercased()
        }
        
        guard let char = keyChar,
              let keyCode = keyCodeForCharacter(char) else {
            return ParsedKeybinding(modifiers: [], keyCode: 0, isValid: false)
        }
        
        return ParsedKeybinding(modifiers: modifiers, keyCode: keyCode, isValid: true)
    }
    
    private func keyCodeForCharacter(_ character: String) -> Int? {
        switch character {
        case "A": return 0
        case "S": return 1
        case "D": return 2
        case "F": return 3
        case "H": return 4
        case "G": return 5
        case "Z": return 6
        case "X": return 7
        case "C": return 8
        case "V": return 9
        case "B": return 11
        case "Q": return 12
        case "W": return 13
        case "E": return 14
        case "R": return 15
        case "Y": return 16
        case "T": return 17
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "6": return 22
        case "5": return 23
        case "=": return 24
        case "9": return 25
        case "7": return 26
        case "-": return 27
        case "8": return 28
        case "0": return 29
        case "]": return 30
        case "O": return 31
        case "U": return 32
        case "[": return 33
        case "I": return 34
        case "P": return 35
        case "L": return 37
        case "J": return 38
        case "'": return 39
        case "K": return 40
        case ";": return 41
        case "\\": return 42
        case ",": return 43
        case "/": return 44
        case "N": return 45
        case "M": return 46
        case ".": return 47
        case "`": return 50
        default: return nil
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
        triggerStartedAt = now
        lastTriggerDate = now
        triggerGeneration &+= 1
        let generation = triggerGeneration
        let delayNanoseconds = UInt64(max(0, settings.trigger.triggerDelayMilliseconds) * 1_000_000)

        pendingBeginTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled,
                  let self,
                  self.triggerGeneration == generation,
                  self.isTriggerDown else { return }
            self.pendingBeginTask = nil
            self.log("keybind begin loop")
            self.delegate?.triggerDidBegin()
        }
    }

    private var isTriggerStale: Bool {
        guard let triggerStartedAt else { return false }
        let timeout = settings.trigger.triggerDelayMilliseconds / 1000 + settings.trigger.timeoutSeconds + 1
        return Date().timeIntervalSince(triggerStartedAt) > max(1, timeout)
    }

    private func log(_ message: String) {
        guard settings.behavior.resizeDiagnostics else { return }
        logger.info("\(message, privacy: .public)")
    }
}
