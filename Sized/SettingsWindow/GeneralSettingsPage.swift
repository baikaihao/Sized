import SwiftUI

struct GeneralSettingsPage: View {
    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject private var accessibility = AccessibilityManager.shared
    @State private var showingResetConfirmation = false
    @State private var launchAtLoginError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                appIdentity

                SettingsSection(title: "通用设置", systemImage: "switch.2") {
                    Toggle("登录时自动启动", isOn: Binding(
                        get: { settings.general.launchAtLogin },
                        set: { enabled in
                            settings.general.launchAtLogin = enabled
                            do {
                                try LaunchAtLoginManager.shared.setEnabled(enabled)
                                launchAtLoginError = nil
                            } catch {
                                launchAtLoginError = error.localizedDescription
                                settings.general.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
                            }
                        }
                    ))

                    if let launchAtLoginError {
                        Label(launchAtLoginError, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Toggle("在菜单栏中显示图标", isOn: $settings.general.showMenuBarIcon)
                    Toggle("隐藏 Dock 图标", isOn: $settings.general.hideDockIcon)
                }

                SettingsSection(title: "辅助功能权限", systemImage: "accessibility") {
                    HStack {
                        Label(
                            accessibility.isTrusted ? "已获得辅助功能权限" : "需要辅助功能权限才能调整其他应用窗口",
                            systemImage: accessibility.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(accessibility.isTrusted ? .green : .orange)

                        Spacer()

                        Button {
                            accessibility.refresh()
                            if !accessibility.isTrusted {
                                accessibility.requestAccess()
                            }
                        } label: {
                            Label(accessibility.isTrusted ? "重新检查" : "打开系统设置", systemImage: "gear")
                        }

                        Button {
                            accessibility.refresh()
                        } label: {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                    }
                }

                SettingsSection(title: "触发键", systemImage: "keyboard") {
                    HStack {
                        Text("快捷键")
                        Spacer()
                        TriggerRecorderButton(displayName: $settings.trigger.triggerKeyDisplayName)
                    }
                    
                    Toggle("使用 Option 键作为触发键", isOn: $settings.trigger.useOptionAsTrigger)
                    
                    if settings.trigger.useOptionAsTrigger {
                        Picker("Option 位置", selection: $settings.trigger.optionSide) {
                            ForEach(OptionSide.allCases) { side in
                                Text(side.displayName).tag(side)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                    
                    SliderRow(title: "触发延迟", value: $settings.trigger.triggerDelayMilliseconds, range: 0...500, step: 10, suffix: "ms")
                    Toggle("双击触发键激活轮盘", isOn: $settings.trigger.doubleTapTrigger)
                    Toggle("鼠标中键激活轮盘", isOn: $settings.trigger.middleClickTrigger)
                }

                SettingsSection(title: "行为设置", systemImage: "cursorarrow.motionlines") {
                    PickerRow(title: "确认方式", selection: $settings.behavior.confirmationMode)
                    Toggle("窗口调整动画", isOn: $settings.behavior.resizeAnimation)
                    PickerRow(title: "改尺寸锚点", selection: $settings.behavior.resizeAnchor)
                    Toggle("忽略全屏窗口", isOn: $settings.behavior.ignoreFullScreenWindows)
                    Toggle("触觉反馈", isOn: $settings.behavior.hapticFeedback)
                    Toggle("窗口调整诊断日志", isOn: $settings.behavior.resizeDiagnostics)
                }

                SettingsSection(title: "重置与支持", systemImage: "questionmark.circle") {
                    HStack {
                        Button(role: .destructive) {
                            showingResetConfirmation = true
                        } label: {
                            Label("重置所有设置", systemImage: "trash")
                        }

                        Spacer()

                        Link(destination: URL(string: "https://github.com/baikaihao/Sized/issues")!) {
                            Label("GitHub Issue", systemImage: "ladybug")
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("确定要重置所有设置吗？", isPresented: $showingResetConfirmation) {
            Button("重置所有设置", role: .destructive) {
                settings.resetAll()
            }
            Button("取消", role: .cancel) {}
        }
        .onAppear {
            settings.general.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
            SizedManager.shared.refreshPermissions()
        }
    }

    private var appIdentity: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 128, height: 128)

            Text("Sized")
                .font(.system(size: 32, weight: .semibold))

            Text("版本 %@ (%@)".localizedFormat(Bundle.main.shortVersion, Bundle.main.buildNumber))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

private struct TriggerRecorderButton: View {
    @Binding var displayName: String
    @State private var isRecording = false

    var body: some View {
        Button {
            isRecording.toggle()
            if isRecording {
                displayName = "按下快捷键...".localized
            }
        } label: {
            Text(displayName)
                .frame(minWidth: 150)
        }
        .keyboardShortcut(.space, modifiers: [])
        .background(KeyCaptureView(isRecording: $isRecording, displayName: $displayName).frame(width: 0, height: 0))
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var displayName: String

    func makeCoordinator() -> Coordinator {
        Coordinator(isRecording: $isRecording, displayName: $displayName)
    }

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: CaptureNSView, context: Context) {
        if isRecording {
            context.coordinator.resetModifiers()
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class Coordinator: NSObject, CaptureNSViewDelegate {
        @Binding var isRecording: Bool
        @Binding var displayName: String
        private var currentModifiers: NSEvent.ModifierFlags = []

        init(isRecording: Binding<Bool>, displayName: Binding<String>) {
            _isRecording = isRecording
            _displayName = displayName
        }

        func resetModifiers() {
            currentModifiers = []
        }

        func flagsChanged(_ flags: NSEvent.ModifierFlags) {
            guard isRecording else { return }
            let modifiers = flags.intersection(.deviceIndependentFlagsMask)
            currentModifiers = modifiers
        }

        func keyDown(_ event: NSEvent) {
            guard isRecording else { return }
            
            if event.keyCode == 53 {
                isRecording = false
                return
            }
            
            let value = TriggerKeyFormatter.displayName(for: currentModifiers, keyCode: event.keyCode)
            if !value.isEmpty {
                displayName = value
                isRecording = false
                currentModifiers = []
            }
        }
    }

    protocol CaptureNSViewDelegate: AnyObject {
        func flagsChanged(_ flags: NSEvent.ModifierFlags)
        func keyDown(_ event: NSEvent)
    }

    final class CaptureNSView: NSView {
        weak var delegate: CaptureNSViewDelegate?

        override var acceptsFirstResponder: Bool { true }

        override func flagsChanged(with event: NSEvent) {
            delegate?.flagsChanged(event.modifierFlags)
        }

        override func keyDown(with event: NSEvent) {
            delegate?.keyDown(event)
        }
    }
}

private enum TriggerKeyFormatter {
    static func displayName(for flags: NSEvent.ModifierFlags, keyCode: UInt16? = nil) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.capsLock) { parts.append("⇪") }
        
        if let keyCode = keyCode, let keyName = keyName(for: keyCode) {
            parts.append(keyName)
        }
        
        return parts.joined()
    }
    
    private static func keyName(for keyCode: UInt16) -> String? {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        case 54: return "Right Command"
        case 55: return "Command"
        case 56: return "Shift"
        case 57: return "Caps Lock"
        case 58: return "Option"
        case 59: return "Control"
        case 60: return "Right Shift"
        case 61: return "Right Option"
        case 62: return "Right Control"
        case 63: return "Function"
        case 64: return "F17"
        case 65: return "."
        case 67: return "*"
        case 69: return "+"
        case 71: return "Clear"
        case 72: return "F18"
        case 73: return "F19"
        case 75: return "/"
        case 76: return "Enter"
        case 78: return "-"
        case 79: return "F20"
        case 80: return "F22"
        case 82: return "F21"
        case 83: return "1"
        case 84: return "2"
        case 85: return "3"
        case 86: return "4"
        case 87: return "5"
        case 88: return "6"
        case 89: return "7"
        case 91: return "8"
        case 92: return "9"
        case 93: return "0"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 115: return "Home"
        case 116: return "Page Up"
        case 117: return "Forward Delete"
        case 118: return "F4"
        case 119: return "End"
        case 120: return "F2"
        case 121: return "Page Down"
        case 122: return "F1"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"
        default: return nil
        }
    }
}

private extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
