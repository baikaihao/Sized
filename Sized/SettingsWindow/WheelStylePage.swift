import SwiftUI

struct WheelStylePage: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var previewSlot: RadialMenuSlot? = .right
    @State private var primaryColor = Color(hex: WheelStyleSettings.default.primaryColorHex)
    @State private var secondaryColor = Color(hex: WheelStyleSettings.default.secondaryColorHex)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "轮盘样式",
                    subtitle: "调整轮盘的尺寸、颜色、显示位置和动画效果。"
                )

                VStack(spacing: 16) {
                    SettingsSection(title: "基础外观", systemImage: "circle.dashed") {
                        Toggle("显示轮盘", isOn: $settings.wheelStyle.isVisible)
                        SliderRow(title: "轮盘大小", value: $settings.wheelStyle.size, range: 60...200, step: 1, suffix: "pt")
                        SliderRow(title: "轮盘厚度", value: $settings.wheelStyle.thickness, range: 10...60, step: 1, suffix: "pt")
                        SliderRow(title: "圆角半径", value: $settings.wheelStyle.cornerRadius, range: 0...50, step: 1, suffix: "pt")
                        SliderRow(title: "中心大小", value: $settings.wheelStyle.centerSize, range: 28...140, step: 1, suffix: "pt")
                        SliderRow(title: "中心圆角", value: $settings.wheelStyle.centerCornerRadius, range: 0...70, step: 1, suffix: "pt")
                        Toggle("锁定到屏幕中心", isOn: $settings.wheelStyle.lockToScreenCenter)
                        Toggle("隐藏无选择时的轮盘", isOn: $settings.wheelStyle.hideWhenNoSelection)
                    }

                    WheelPreviewPanel(
                        selectedSlot: $previewSlot,
                        action: previewSlot.map { settings.assignments[$0] },
                        assignments: settings.assignments,
                        style: settings.wheelStyle
                    )

                    SettingsSection(title: "动画", systemImage: "sparkles") {
                        Toggle("出现动画", isOn: $settings.wheelStyle.appearanceAnimation)
                        PickerRow(title: "大小变化动画", selection: $settings.wheelStyle.sizeAnimation)
                        PickerRow(title: "角度变化动画", selection: $settings.wheelStyle.angleAnimation)
                    }

                    SettingsSection(title: "强调色", systemImage: "eyedropper") {
                        PickerRow(title: "颜色模式", selection: $settings.wheelStyle.accentColorMode)
                        ColorPicker("主色", selection: $primaryColor, supportsOpacity: false)
                            .disabled(settings.wheelStyle.accentColorMode == .system)
                            .onChange(of: primaryColor) { _, newValue in
                                settings.wheelStyle.primaryColorHex = newValue.hexString
                            }
                        Toggle("使用渐变", isOn: $settings.wheelStyle.useGradient)
                        ColorPicker("渐变色", selection: $secondaryColor, supportsOpacity: false)
                            .disabled(!settings.wheelStyle.useGradient)
                            .onChange(of: secondaryColor) { _, newValue in
                                settings.wheelStyle.secondaryColorHex = newValue.hexString
                            }
                    }
                }
            }
            .padding(32)
        }
        .onAppear {
            primaryColor = Color(hex: settings.wheelStyle.primaryColorHex)
            secondaryColor = Color(hex: settings.wheelStyle.secondaryColorHex)
        }
    }
}

struct WheelPreviewPanel: View {
    @Binding var selectedSlot: RadialMenuSlot?
    var action: RadialMenuAction?
    var assignments: AssignmentSettings
    var style: WheelStyleSettings

    var body: some View {
        SettingsSection(title: "实时预览", systemImage: "eye") {
            VStack(spacing: 20) {
                ZStack {
                    RadialMenuView(
                        selectedSlot: selectedSlot,
                        action: action,
                        assignments: assignments,
                        style: style,
                        hasTargetWindow: true,
                        isShown: true,
                        isPreview: true
                    )
                    .frame(width: max(RadialMenuView.canvasSize(for: style) + 16, 220), height: max(RadialMenuView.canvasSize(for: style) + 16, 220))
                }
                .frame(maxWidth: .infinity)
                .frame(height: max(RadialMenuView.canvasSize(for: style) + 28, 240))

                Picker("模拟选择", selection: $selectedSlot) {
                    Text("无选择").tag(nil as RadialMenuSlot?)
                    ForEach(RadialMenuSlot.visualOrder) { slot in
                        Text(slot.displayName).tag(Optional(slot))
                    }
                }
                .pickerStyle(.menu)

                Text(selectedSlot == nil ? "未选择".localized : action?.displayName ?? "未选择".localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct PageHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.localized)
                .font(.system(size: 30, weight: .semibold))
            Text(subtitle.localized)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsSection<Content: View>: View {
    var title: String
    var systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title.localized, systemImage: systemImage)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary)
        }
    }
}

struct SliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.localized)
                Spacer()
                Text("\(Int(value))\(suffix.localized)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

struct SliderRowDecimal: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var suffix: String
    var format: String = "%.2f"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.localized)
                Spacer()
                Text(String(format: "\(format)\(suffix.localized)", value))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

struct PickerRow<Value: Hashable & CaseIterable & Identifiable>: View where Value.AllCases: RandomAccessCollection {
    var title: String
    @Binding var selection: Value

    var body: some View {
        HStack {
            Text(title.localized)
            Spacer()
            Picker(title, selection: $selection) {
                ForEach(Array(Value.allCases)) { value in
                    Text(displayName(for: value)).tag(value)
                }
            }
            .labelsHidden()
            .frame(width: 180)
        }
    }

    private func displayName(for value: Value) -> String {
        if let value = value as? AccentColorMode { return value.displayName }
        if let value = value as? RadialAnimationStyle { return value.displayName }
        if let value = value as? ConfirmationMode { return value.displayName }
        if let value = value as? ResizeAnchor { return value.displayName }
        return String(describing: value)
    }
}
