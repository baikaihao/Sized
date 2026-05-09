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
    private var currentOptionKeycode: Int64 = 0
    private var currentTriggerKeycode: Int64 = 0
    private var pendingWorkItem: DispatchWorkItem?
    private var lastTriggerDate: Date?
    private var settings: SettingsStore { .shared }
    
    private struct ParsedKeybinding {
        let modifiers: CGEventFlags
        let keyCode: Int
        let isValid: Bool
    }

    func start() {
        guard monitor == nil else { return }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
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
        currentOptionKeycode = 0
        currentTriggerKeycode = 0
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            if keyCode == 53, isTriggerDown, settings.behavior.escapeCancelsRadial {
                delegate?.triggerDidCancel()
                isTriggerDown = false
                return
            }

            if !settings.trigger.useOptionAsTrigger {
                let keybinding = parseKeybinding(settings.trigger.triggerKeyDisplayName)
                let eventModifiers = event.flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])

                if keybinding.isValid &&
                   keyCode == keybinding.keyCode &&
                   eventModifiers == keybinding.modifiers &&
                   !isTriggerDown {
                    currentTriggerKeycode = Int64(keyCode)
                    beginTrigger()
                    return
                }

                if !isTriggerDown { return }

                if keyCode == keybinding.keyCode && eventModifiers == keybinding.modifiers {
                    return
                } else {
                    pendingWorkItem?.cancel()
                    pendingWorkItem = nil
                    isTriggerDown = false
                    currentTriggerKeycode = 0
                    delegate?.triggerDidEnd(confirm: true)
                }
            }
            return
        }

        if type == .keyUp {
            guard isTriggerDown, !settings.trigger.useOptionAsTrigger else { return }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if Int64(keyCode) == currentTriggerKeycode {
                pendingWorkItem?.cancel()
                pendingWorkItem = nil
                isTriggerDown = false
                currentTriggerKeycode = 0
                delegate?.triggerDidEnd(confirm: true)
            }
            return
        }

        guard type == .flagsChanged else { return }

        let flags = event.flags
        let optionDown = flags.contains(.maskAlternate)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
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
                currentOptionKeycode = 0
                pendingWorkItem?.cancel()
                pendingWorkItem = nil
                isTriggerDown = false
                delegate?.triggerDidEnd(confirm: true)
            }
        } else if isTriggerDown {
            let keybinding = parseKeybinding(settings.trigger.triggerKeyDisplayName)
            guard keybinding.isValid else { return }
            let triggerModifiers = keybinding.modifiers
            let currentModifiers = flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])
            if !triggerModifiers.isEmpty && currentModifiers.intersection(triggerModifiers).isEmpty {
                pendingWorkItem?.cancel()
                pendingWorkItem = nil
                isTriggerDown = false
                currentTriggerKeycode = 0
                delegate?.triggerDidEnd(confirm: true)
            }
        }
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
        lastTriggerDate = now

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.delegate?.triggerDidBegin()
            }
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.trigger.triggerDelayMilliseconds / 1000, execute: workItem)
    }
}
