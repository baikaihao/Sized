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
                    Label("隐藏 Dock 图标需要重新启动应用后完全生效。", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                            if accessibility.isTrusted {
                                accessibility.refresh()
                            } else {
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
                        Text("触发键")
                        Spacer()
                        TriggerRecorderButton(displayName: $settings.trigger.triggerKeyDisplayName)
                    }
                    SliderRow(title: "触发延迟", value: $settings.trigger.triggerDelayMilliseconds, range: 0...500, step: 10, suffix: "ms")
                    Toggle("双击触发键激活轮盘", isOn: $settings.trigger.doubleTapTrigger)
                    Toggle("鼠标中键触发轮盘", isOn: $settings.trigger.middleClickTrigger)
                    SliderRow(title: "触发键超时", value: $settings.trigger.timeoutSeconds, range: 1...10, step: 1, suffix: "s")
                }

                SettingsSection(title: "行为设置", systemImage: "cursorarrow.motionlines") {
                    PickerRow(title: "确认方式", selection: $settings.behavior.confirmationMode)
                    Toggle("窗口调整动画", isOn: $settings.behavior.resizeAnimation)
                    PickerRow(title: "改尺寸锚点", selection: $settings.behavior.resizeAnchor)
                    Toggle("忽略全屏窗口", isOn: $settings.behavior.ignoreFullScreenWindows)
                    Toggle("触觉反馈", isOn: $settings.behavior.hapticFeedback)
                }

                SettingsSection(title: "预览窗口", systemImage: "rectangle.dashed") {
                    Toggle("显示目标尺寸预览", isOn: $settings.behavior.showPreview)
                    SliderRow(title: "预览内边距", value: $settings.behavior.previewPadding, range: 0...30, step: 1, suffix: "pt")
                    SliderRow(title: "圆角半径", value: $settings.behavior.previewCornerRadius, range: 0...28, step: 1, suffix: "pt")
                    SliderRow(title: "边框宽度", value: $settings.behavior.previewBorderWidth, range: 1...6, step: 1, suffix: "pt")
                }

                SettingsSection(title: "重置与支持", systemImage: "questionmark.circle") {
                    HStack {
                        Button(role: .destructive) {
                            showingResetConfirmation = true
                        } label: {
                            Label("重置所有设置", systemImage: "trash")
                        }

                        Spacer()

                        Link(destination: URL(string: "mailto:support@example.com")!) {
                            Label("反馈邮件", systemImage: "envelope")
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
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.thinMaterial)
                    .frame(width: 128, height: 128)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.quaternary)
                    }

                Image(systemName: "circle.grid.cross.fill")
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            Text("Sized")
                .font(.system(size: 32, weight: .semibold))

            Text("版本 \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
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
                displayName = "按下修饰键..."
            }
        } label: {
            Label(displayName, systemImage: isRecording ? "record.circle" : "option")
                .frame(minWidth: 150)
        }
        .keyboardShortcut(.space, modifiers: [])
        .background(KeyCaptureView(isRecording: $isRecording, displayName: $displayName).frame(width: 0, height: 0))
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var displayName: String

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.onFlagsChanged = { flags in
            guard isRecording else { return }
            let value = TriggerKeyFormatter.displayName(for: flags)
            if !value.isEmpty {
                displayName = value
                isRecording = false
            }
        }
        return view
    }

    func updateNSView(_ nsView: CaptureNSView, context: Context) {
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class CaptureNSView: NSView {
        var onFlagsChanged: ((NSEvent.ModifierFlags) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func flagsChanged(with event: NSEvent) {
            onFlagsChanged?(event.modifierFlags)
        }
    }
}

private enum TriggerKeyFormatter {
    static func displayName(for flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.capsLock) { parts.append("⇪") }
        return parts.joined()
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
